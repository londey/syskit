#!/bin/bash
# Find the next task to implement and run pre-implementation checks
# Usage: find-task.sh [task-number]
#   No argument: finds first pending task
#   With argument: selects that specific task
#
# Output is structured for machine parsing:
#   FIND_TASK_START
#   task_folder: <path>
#   task_file: <path>
#   task_number: <N>
#   task_title: <title>
#   task_status: <status>
#   freshness: fresh|stale
#   freshness_detail: <manifest-check output>
#   deps_ok: true|false
#   deps_detail: <dependency check output>
#   pending_remaining: <count>
#   all_complete: true|false
#   FIND_TASK_END
#
# Exit codes: 0 = task found, 1 = error, 2 = all tasks complete
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TASKS_DIR="$PROJECT_ROOT/.syskit/tasks"
REQUESTED_TASK="${1:-}"

# ─── Find most recent task folder ───────────────────────────────

if [ ! -d "$TASKS_DIR" ]; then
    echo "Error: no .syskit/tasks/ directory found" >&2
    exit 1
fi

TASK_FOLDER=$(ls -dt "$TASKS_DIR"/*/ 2>/dev/null | head -1)

if [ -z "$TASK_FOLDER" ]; then
    echo "Error: no task folders found in .syskit/tasks/" >&2
    echo "Run /syskit-plan first to create an implementation plan." >&2
    exit 1
fi

# Remove trailing slash for consistency
TASK_FOLDER="${TASK_FOLDER%/}"

# ─── Read task sequence from plan.md ─────────────────────────────

PLAN_FILE="$TASK_FOLDER/plan.md"

if [ ! -f "$PLAN_FILE" ]; then
    echo "Error: plan.md not found in $TASK_FOLDER" >&2
    exit 1
fi

# Show first ~30 lines (task sequence table) for context
PLAN_HEADER=$(head -30 "$PLAN_FILE")

# ─── Find the target task ────────────────────────────────────────

TASK_FILE=""
TASK_NUMBER=""
TASK_TITLE=""
TASK_STATUS=""
PENDING_COUNT=0
ALL_COMPLETE=true

for f in "$TASK_FOLDER"/task_[0-9][0-9][0-9]_*.md; do
    [ -f "$f" ] || continue

    # Read first 5 lines to get status
    header=$(head -5 "$f")
    status=$(echo "$header" | grep -oP 'Status:\s*\K\S+' || echo "unknown")
    title=$(echo "$header" | head -1 | sed 's/^#\+ *//')
    num=$(basename "$f" | grep -oP 'task_\K[0-9]+')

    if [ "$status" = "Pending" ]; then
        PENDING_COUNT=$((PENDING_COUNT + 1))
        ALL_COMPLETE=false
    elif [ "$status" != "Complete" ] && [ "$status" != "Done" ]; then
        ALL_COMPLETE=false
    fi

    if [ -n "$REQUESTED_TASK" ]; then
        # Match by task number (with or without leading zeros)
        if [[ "$REQUESTED_TASK" =~ ^[0-9]+$ ]]; then
            req_num=$((10#$REQUESTED_TASK))
        else
            req_num="$REQUESTED_TASK"
        fi
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            file_num=$((10#$num))
        else
            file_num="$num"
        fi
        if [ "$req_num" = "$file_num" ] && [ -z "$TASK_FILE" ]; then
            TASK_FILE="$f"
            TASK_NUMBER="$num"
            TASK_TITLE="$title"
            TASK_STATUS="$status"
        fi
    else
        # Pick first pending task
        if [ "$status" = "Pending" ] && [ -z "$TASK_FILE" ]; then
            TASK_FILE="$f"
            TASK_NUMBER="$num"
            TASK_TITLE="$title"
            TASK_STATUS="$status"
        fi
    fi
done

# ─── Handle "all complete" case ──────────────────────────────────

if [ -z "$TASK_FILE" ]; then
    if [ "$ALL_COMPLETE" = true ]; then
        echo "FIND_TASK_START"
        echo "task_folder: $TASK_FOLDER"
        echo "all_complete: true"
        echo "pending_remaining: 0"
        echo "FIND_TASK_END"
        exit 2
    elif [ -n "$REQUESTED_TASK" ]; then
        echo "Error: task $REQUESTED_TASK not found in $TASK_FOLDER" >&2
        exit 1
    else
        echo "Error: no pending tasks found but not all are complete" >&2
        exit 1
    fi
fi

# ─── Freshness check ────────────────────────────────────────────

SNAPSHOT="$TASK_FOLDER/snapshot.md"
FRESHNESS="fresh"
FRESHNESS_DETAIL=""

if [ -f "$SNAPSHOT" ]; then
    FRESHNESS_DETAIL=$("$SCRIPT_DIR/manifest-check.sh" "$SNAPSHOT" 2>&1) && true
    if [ $? -ne 0 ]; then
        FRESHNESS="stale"
    fi
else
    FRESHNESS_DETAIL="No snapshot file found — skipping freshness check."
fi

# ─── Dependency check ────────────────────────────────────────────

DEPS_OK=true
DEPS_DETAIL=""

# Read Dependencies line from the task file
DEPS_LINE=$(head -5 "$TASK_FILE" | grep -i 'Dependencies:' || true)

if [ -n "$DEPS_LINE" ]; then
    # Extract task numbers from dependencies (e.g., "Dependencies: 1, 2" or "Dependencies: task_001, task_002")
    dep_nums=$(echo "$DEPS_LINE" | grep -oE '[0-9]+' || true)

    for dep_num in $dep_nums; do
        # Skip if it's the same task
        if [[ "$TASK_NUMBER" =~ ^[0-9]+$ ]]; then
            task_num_int=$((10#$TASK_NUMBER))
        else
            task_num_int="$TASK_NUMBER"
        fi
        if [[ "$dep_num" =~ ^[0-9]+$ ]]; then
            dep_num_int=$((10#$dep_num))
        else
            dep_num_int="$dep_num"
        fi
        [ "$dep_num_int" = "$task_num_int" ] && continue

        # Find the dependency task file
        dep_padded=$(printf "%03d" "$dep_num_int")
        dep_file=$(ls "$TASK_FOLDER"/task_${dep_padded}_*.md 2>/dev/null | head -1)

        if [ -z "$dep_file" ]; then
            DEPS_OK=false
            DEPS_DETAIL="${DEPS_DETAIL}✗ Task $dep_num: file not found\n"
            continue
        fi

        dep_status=$(head -5 "$dep_file" | grep -oP 'Status:\s*\K\S+' || echo "unknown")
        if [ "$dep_status" = "Complete" ] || [ "$dep_status" = "Done" ]; then
            DEPS_DETAIL="${DEPS_DETAIL}✓ Task $dep_num: $dep_status\n"
        else
            DEPS_OK=false
            DEPS_DETAIL="${DEPS_DETAIL}✗ Task $dep_num: $dep_status (not complete)\n"
        fi
    done
else
    DEPS_DETAIL="No dependencies."
fi

# ─── Output structured result ────────────────────────────────────

echo "FIND_TASK_START"
echo "task_folder: $TASK_FOLDER"
echo "task_file: $TASK_FILE"
echo "task_number: $TASK_NUMBER"
echo "task_title: $TASK_TITLE"
echo "task_status: $TASK_STATUS"
echo "freshness: $FRESHNESS"
echo "freshness_detail: $(echo "$FRESHNESS_DETAIL" | head -20)"
echo "deps_ok: $DEPS_OK"
echo "deps_detail: $(echo -e "$DEPS_DETAIL")"
echo "pending_remaining: $PENDING_COUNT"
echo "all_complete: false"
echo ""
echo "## Plan Overview"
echo "$PLAN_HEADER"
echo "FIND_TASK_END"
