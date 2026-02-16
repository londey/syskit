#!/bin/bash
# syskit installer
# Generated - do not edit directly. Modify templates/ and run build/generate-installer.sh
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[syskit]${NC} $1"; }
warn() { echo -e "${YELLOW}[syskit]${NC} $1"; }
error() { echo -e "${RED}[syskit]${NC} $1"; exit 1; }

# Check we're in a reasonable location
if [ ! -d ".git" ] && [ "$1" != "--force" ]; then
    warn "Not in a git repository root. Use --force to install anyway."
    exit 1
fi

info "Installing syskit in: $(pwd)"

# Create directory structure
info "Creating directories..."
mkdir -p doc/requirements
mkdir -p doc/interfaces
mkdir -p doc/design
mkdir -p .syskit/scripts
mkdir -p .syskit/prompts
mkdir -p .syskit/ref
mkdir -p .syskit/analysis
mkdir -p .syskit/tasks
mkdir -p .syskit/templates/doc/requirements
mkdir -p .syskit/templates/doc/interfaces
mkdir -p .syskit/templates/doc/design
mkdir -p .claude/commands


# --- .syskit/AGENTS.md ---
info "Creating .syskit/AGENTS.md"
cat > ".syskit/AGENTS.md" << '__SYSKIT_TEMPLATE_END__'
# syskit — AI Assistant Instructions

This project uses syskit for specification-driven development.

**New to syskit?** Run `/syskit-guide` for an interactive walkthrough.

## Document Locations

All persistent engineering documents live under `doc/`:

- `doc/requirements/` — What the system must do
- `doc/interfaces/` — Contracts between components and with external systems
- `doc/design/` — How the system accomplishes requirements

Working documents live under `.syskit/`:

- `.syskit/analysis/` — Impact analysis results (ephemeral)
- `.syskit/tasks/` — Implementation task plans (ephemeral)
- `.syskit/manifest.md` — SHA256 hashes of all doc files

Reference material for subagents:

- `.syskit/ref/` — Detailed format specs (requirement quality, cross-references, Spec-ref)
- `.syskit/prompts/` — Subagent prompt templates

## Document Types

- **Requirements** (`req_NNN_<name>.md`) — WHAT the system must do. Use condition/response format.
- **Interfaces** (`int_NNN_<name>.md`) — Contracts between components and external systems.
- **Design Units** (`unit_NNN_<name>.md`) — HOW the system works. Links to requirements and interfaces.

For detailed format specifications, see `.syskit/ref/document-formats.md`.

## Workflows

### Before Making Changes

Always run impact analysis first:

1. Read the manifest to get the current document inventory
2. Delegate document reading and analysis to a subagent — subagent writes results to disk and returns only a brief summary
3. Validate the subagent's summary counts against the manifest
4. Check manifest for any documents modified since last analysis

### Proposing Changes

1. Ensure `doc/` has no uncommitted changes (clean git status required)
2. Create analysis folder: `.syskit/analysis/<date>_<change_name>/`
3. Delegate change drafting to subagent(s) — subagents read impact.md from disk, edit `doc/` files directly, and write a lightweight summary to `proposed_changes.md`
4. Generate `snapshot.md` by running: `.syskit/scripts/manifest-snapshot.sh <analysis-folder>`
5. User reviews changes via `git diff doc/` and approves, revises, or rejects

### Planning Implementation

After spec changes are approved:

1. Delegate scope extraction and task creation to a subagent — subagent reads proposed_changes.md and `git diff`, writes plan.md and task files to disk
2. Generate `snapshot.md` by running: `.syskit/scripts/manifest-snapshot.sh <task-folder>`
3. Tasks should be small enough to implement and verify independently

### Implementing

1. Delegate implementation to a subagent — subagent reads the task file and all referenced files, makes changes, verifies, returns a summary
2. After each task, run post-implementation scripts to verify consistency
3. Run `.syskit/scripts/trace-sync.sh` to verify cross-references are consistent
4. Run `.syskit/scripts/impl-stamp.sh UNIT-NNN` for each modified unit to update Spec-ref hashes
5. Run `.syskit/scripts/impl-check.sh` to verify implementation freshness
6. After doc changes, run `.syskit/scripts/manifest.sh` to update the manifest

### Context Budget Management

The workflow commands use subagents to keep document content out of the main context window. Follow these rules to prevent context exhaustion:

1. **Subagents write to disk, return only summaries** — A subagent's final message becomes a tool result in the main context. Keep return messages under 1KB. Write detailed output to files in `.syskit/analysis/` or `.syskit/tasks/`.

2. **Subagents read large files from disk** — Never paste file content larger than 2KB into a subagent prompt. Instead, give the subagent the file path and let it read the file itself.

3. **Chunk large change sets** — When more than 8 documents are affected, use multiple subagents each handling a subset. Assemble results with `.syskit/scripts/assemble-chunks.sh`.

4. **Validate via summaries, not content** — Verify subagent work by checking counts and file lists in the returned summary. Do not read large output files into the main context for review.

5. **Edit doc files directly** — Subagents edit `doc/` files in place. The user reviews via `git diff`. This eliminates the largest context consumer (full proposed content for every affected file).

6. **One command per conversation** — Each syskit command persists all state to disk. Start a fresh conversation for each command to avoid context accumulation.

## Freshness Checking

Analysis and task files include SHA256 snapshots of referenced documents.

When loading previous analysis or tasks, run the check script:

```bash
.syskit/scripts/manifest-check.sh <path-to-snapshot.md>
```

Exit code 0 means all documents are fresh; exit code 1 means some have changed.

## File Numbering

When creating new documents:

- Find highest existing number in that category
- Use next number with 3-digit padding: `001`, `002`, etc.
- Use `_` separator, lowercase, no spaces in names

Helper scripts:

```bash
.syskit/scripts/new-req.sh <name>
.syskit/scripts/new-req.sh --parent REQ-004 <name>
.syskit/scripts/new-int.sh <name>
.syskit/scripts/new-unit.sh <name>
```

## Cross-References

Use `REQ-NNN`, `INT-NNN`, `UNIT-NNN` identifiers when referencing between documents.

For detailed cross-reference rules and the sync tool, see `.syskit/ref/cross-references.md`.

For Spec-ref implementation traceability, see `.syskit/ref/spec-ref.md`.
__SYSKIT_TEMPLATE_END__

# --- .syskit/scripts/assemble-chunks.sh ---
info "Creating .syskit/scripts/assemble-chunks.sh"
cat > ".syskit/scripts/assemble-chunks.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Assemble chunk files into a single document
# Usage: assemble-chunks.sh <output-file> <chunk-dir> [chunk-pattern]
#   Concatenates sorted chunk files with --- separators
set -e

OUTFILE="${1:?Usage: assemble-chunks.sh <output-file> <chunk-dir> [chunk-pattern]}"
CHUNK_DIR="${2:?Usage: assemble-chunks.sh <output-file> <chunk-dir> [chunk-pattern]}"
PATTERN="${3:-chunk_*.md}"

if [ ! -d "$CHUNK_DIR" ]; then
    echo "Error: chunk directory does not exist: $CHUNK_DIR" >&2
    exit 1
fi

# Find chunk files
CHUNKS=$(find "$CHUNK_DIR" -maxdepth 1 -name "$PATTERN" 2>/dev/null | LC_COLLATE=C sort)

if [ -z "$CHUNKS" ]; then
    echo "Error: no chunk files matching '$PATTERN' in $CHUNK_DIR" >&2
    exit 1
fi

# Start with empty output (or existing file if it has a header)
FIRST=true
for chunk in $CHUNKS; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "" >> "$OUTFILE"
        echo "---" >> "$OUTFILE"
        echo "" >> "$OUTFILE"
    fi
    cat "$chunk" >> "$OUTFILE"
done

COUNT=$(echo "$CHUNKS" | wc -l | tr -d ' ')
echo "Assembled $COUNT chunks into: $OUTFILE"
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/assemble-chunks.sh"

# --- .syskit/scripts/find-task.sh ---
info "Creating .syskit/scripts/find-task.sh"
cat > ".syskit/scripts/find-task.sh" << '__SYSKIT_TEMPLATE_END__'
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
        req_num=$((10#$REQUESTED_TASK)) 2>/dev/null || req_num="$REQUESTED_TASK"
        file_num=$((10#$num)) 2>/dev/null || file_num="$num"
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
        task_num_int=$((10#$TASK_NUMBER))
        dep_num_int=$((10#$dep_num))
        [ "$dep_num_int" -eq "$task_num_int" ] 2>/dev/null && continue

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
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/find-task.sh"

# --- .syskit/scripts/impl-check.sh ---
info "Creating .syskit/scripts/impl-check.sh"
cat > ".syskit/scripts/impl-check.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Check implementation freshness via Spec-ref comment hashes
# Usage: impl-check.sh [UNIT-NNN | unit_NNN_name.md]
#   No argument: full scan, generates .syskit/impl-status.md
#   With argument: filter to one unit, stdout only
# Exit codes: 0 = all current, 1 = stale or issues found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UNIT_DIR="$PROJECT_ROOT/doc/design"
REPORT="$PROJECT_ROOT/.syskit/impl-status.md"
FILTER="${1:-}"

cd "$PROJECT_ROOT"

# Require bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: bash 4+ required (found ${BASH_VERSION})" >&2
    exit 1
fi

# ─── Cross-platform hash command ─────────────────────────────────

if command -v sha256sum &> /dev/null; then
    hash_cmd() { sha256sum "$1" | cut -c1-16; }
else
    hash_cmd() { shasum -a 256 "$1" | cut -c1-16; }
fi

# ─── Resolve UNIT filter ─────────────────────────────────────────

FILTER_BASENAME=""

if [ -n "$FILTER" ]; then
    # Try direct basename match
    if [ -f "$UNIT_DIR/$FILTER" ]; then
        FILTER_BASENAME="$FILTER"
    else
        # Extract 3-digit number from UNIT-NNN, unit-NNN, etc.
        num=$(echo "$FILTER" | grep -oE '[0-9]{3}' | head -1)
        if [ -z "$num" ]; then
            echo "Error: cannot parse unit number from '$FILTER'" >&2
            exit 1
        fi
        matches=("$UNIT_DIR"/unit_${num}_*.md)
        if [ -f "${matches[0]}" ]; then
            FILTER_BASENAME=$(basename "${matches[0]}")
        else
            echo "Error: no unit file found for '$FILTER'" >&2
            exit 1
        fi
    fi
fi

# ─── Scan for Spec-ref lines ─────────────────────────────────────

# source_file -> unit_basename:hash:date (one entry per Spec-ref line)
declare -A SPEC_REFS        # "src_file|unit_basename" -> "hash date"
declare -a REF_KEYS=()      # ordered list of "src_file|unit_basename" keys

scan_spec_refs() {
    local files
    files=$(git ls-files --cached --others --exclude-standard 2>/dev/null | xargs grep -lI "Spec-ref:" 2>/dev/null || true)

    [ -z "$files" ] && return

    local src_file line unit_basename ref_hash ref_date
    for src_file in $files; do
        while IFS= read -r line; do
            # Extract unit filename
            unit_basename=$(echo "$line" | sed -n 's/.*Spec-ref:[[:space:]]*\([^ ]*\.md\).*/\1/p')
            [ -z "$unit_basename" ] && continue

            # Apply filter
            if [ -n "$FILTER_BASENAME" ] && [ "$unit_basename" != "$FILTER_BASENAME" ]; then
                continue
            fi

            # Extract hash (16 hex chars between backticks)
            ref_hash=$(echo "$line" | sed -n 's/.*`\([0-9a-f]\{16\}\)`.*/\1/p')
            [ -z "$ref_hash" ] && continue

            # Extract date
            ref_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | tail -1)
            [ -z "$ref_date" ] && ref_date="unknown"

            local key="${src_file}|${unit_basename}"
            SPEC_REFS["$key"]="$ref_hash $ref_date"
            REF_KEYS+=("$key")
        done < <(grep "Spec-ref:" "$src_file")
    done
}

# ─── Parse Implementation sections from unit files ────────────────

declare -A UNIT_IMPL_FILES  # unit_basename -> newline-separated list of file paths

parse_impl_sections() {
    local f base impl_files
    for f in "$UNIT_DIR"/unit_[0-9][0-9][0-9]_*.md; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        [[ "$base" == *_000_template* ]] && continue

        # Apply filter
        if [ -n "$FILTER_BASENAME" ] && [ "$base" != "$FILTER_BASENAME" ]; then
            continue
        fi

        impl_files=$(awk '
            BEGIN { found = 0 }
            $0 == "## Implementation" { found = 1; next }
            found && /^#/ { match($0, /^#+/); if (RLENGTH <= 2) exit }
            found && /^- `[^`]+`/ {
                match($0, /`[^`]+`/)
                path = substr($0, RSTART+1, RLENGTH-2)
                if (path !~ /[<>]/) print path
            }
        ' "$f")

        [ -n "$impl_files" ] && UNIT_IMPL_FILES["$base"]="$impl_files"
    done
}

# ─── Compare hashes ──────────────────────────────────────────────

CURRENT_COUNT=0
STALE_COUNT=0
MISSING_COUNT=0

declare -a RESULT_LINES=()  # "status|src_file|unit_basename|ref_hash|current_hash|ref_date"

compare_hashes() {
    local key src_file unit_basename ref_hash ref_date current_hash unit_path status
    for key in "${REF_KEYS[@]}"; do
        src_file="${key%%|*}"
        unit_basename="${key##*|}"
        ref_hash=$(echo "${SPEC_REFS[$key]}" | cut -d' ' -f1)
        ref_date=$(echo "${SPEC_REFS[$key]}" | cut -d' ' -f2)

        unit_path="$UNIT_DIR/$unit_basename"
        if [ ! -f "$unit_path" ]; then
            status="missing"
            current_hash="n/a"
            MISSING_COUNT=$((MISSING_COUNT + 1))
        else
            current_hash=$(hash_cmd "$unit_path")
            if [ "$ref_hash" = "$current_hash" ]; then
                status="current"
                CURRENT_COUNT=$((CURRENT_COUNT + 1))
            else
                status="stale"
                STALE_COUNT=$((STALE_COUNT + 1))
            fi
        fi

        RESULT_LINES+=("${status}|${src_file}|${unit_basename}|${ref_hash}|${current_hash}|${ref_date}")
    done
}

# ─── Find untracked units ────────────────────────────────────────

UNTRACKED_COUNT=0

declare -a UNTRACKED_LINES=()  # "unit_basename|impl_files"

find_untracked() {
    local unit_basename impl_list has_any_ref impl_path key
    for unit_basename in "${!UNIT_IMPL_FILES[@]}"; do
        impl_list="${UNIT_IMPL_FILES[$unit_basename]}"
        has_any_ref=false

        while IFS= read -r impl_path; do
            [ -z "$impl_path" ] && continue
            key="${impl_path}|${unit_basename}"
            if [ -n "${SPEC_REFS[$key]:-}" ]; then
                has_any_ref=true
                break
            fi
        done <<< "$impl_list"

        if ! $has_any_ref; then
            # Collapse newlines to comma-separated for display
            local display_files
            display_files=$(echo "$impl_list" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            UNTRACKED_LINES+=("${unit_basename}|${display_files}")
            UNTRACKED_COUNT=$((UNTRACKED_COUNT + 1))
        fi
    done
}

# ─── Report generation ───────────────────────────────────────────

generate_report() {
    local out="/dev/stdout"
    if [ -z "$FILTER" ]; then
        out="$REPORT"
    fi

    {
        echo "# Implementation Status"
        echo ""
        echo "Generated: $(date -Iseconds 2>/dev/null || date)"
        echo ""
        echo "## Summary"
        echo ""
        echo "- Current: $CURRENT_COUNT"
        echo "- Stale: $STALE_COUNT"
        echo "- Missing unit: $MISSING_COUNT"
        echo "- Untracked units: $UNTRACKED_COUNT"
        echo ""

        if [ ${#RESULT_LINES[@]} -gt 0 ]; then
            echo "## Spec-ref Status"
            echo ""
            echo "| Source File | Unit | Ref Hash | Current Hash | Status | Sync Date |"
            echo "|------------|------|----------|--------------|--------|-----------|"

            local entry status src_file unit_basename ref_hash current_hash ref_date
            for entry in "${RESULT_LINES[@]}"; do
                IFS='|' read -r status src_file unit_basename ref_hash current_hash ref_date <<< "$entry"
                # Derive UNIT-NNN from basename
                local unit_num
                unit_num=$(echo "$unit_basename" | sed -n 's/unit_\([0-9][0-9][0-9]\)_.*/\1/p')
                local unit_id="UNIT-${unit_num}"
                echo "| \`$src_file\` | $unit_id | \`$ref_hash\` | \`$current_hash\` | $status | $ref_date |"
            done
            echo ""
        fi

        if [ ${#UNTRACKED_LINES[@]} -gt 0 ]; then
            echo "## Untracked Units"
            echo ""
            echo "| Unit | Listed Implementation Files |"
            echo "|------|-----------------------------|"

            local entry unit_basename impl_files unit_num unit_id
            for entry in "${UNTRACKED_LINES[@]}"; do
                unit_basename="${entry%%|*}"
                impl_files="${entry##*|}"
                unit_num=$(echo "$unit_basename" | sed -n 's/unit_\([0-9][0-9][0-9]\)_.*/\1/p')
                unit_id="UNIT-${unit_num}"
                echo "| $unit_id | \`$impl_files\` |"
            done
            echo ""
        fi
    } > "$out"

    if [ -z "$FILTER" ]; then
        echo "Report written: $REPORT"
    fi
}

# ─── Stdout summary ──────────────────────────────────────────────

print_summary() {
    local entry status src_file unit_basename

    for entry in "${RESULT_LINES[@]}"; do
        IFS='|' read -r status src_file unit_basename _ _ _ <<< "$entry"
        case "$status" in
            current) echo "✓ current — $src_file" ;;
            stale)   echo "⚠ stale   — $src_file" ;;
            missing) echo "✗ missing — $src_file (references $unit_basename)" ;;
        esac
    done

    for entry in "${UNTRACKED_LINES[@]}"; do
        unit_basename="${entry%%|*}"
        echo "○ untracked — $unit_basename"
    done
}

# ─── Main ─────────────────────────────────────────────────────────

scan_spec_refs
parse_impl_sections
compare_hashes
find_untracked

if [ -z "$FILTER" ]; then
    generate_report
    echo ""
    print_summary
else
    generate_report
fi

echo ""
TOTAL=$((STALE_COUNT + MISSING_COUNT + UNTRACKED_COUNT))

if [ "$TOTAL" -eq 0 ] && [ $((CURRENT_COUNT + UNTRACKED_COUNT)) -eq 0 ]; then
    echo "No Spec-ref lines found."
elif [ "$TOTAL" -eq 0 ]; then
    echo "All implementations are current."
else
    echo "Summary: $CURRENT_COUNT current, $STALE_COUNT stale, $MISSING_COUNT missing, $UNTRACKED_COUNT untracked"
fi

exit $((TOTAL > 0 ? 1 : 0))
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/impl-check.sh"

# --- .syskit/scripts/impl-stamp.sh ---
info "Creating .syskit/scripts/impl-stamp.sh"
cat > ".syskit/scripts/impl-stamp.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Update Spec-ref hashes in implementation files for a given design unit
# Usage: impl-stamp.sh <UNIT-NNN | unit_NNN_name.md>
# Exit codes: 0 = all updated, 1 = warnings
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UNIT_DIR="$PROJECT_ROOT/doc/design"

UNIT_ARG="${1:-}"

if [ -z "$UNIT_ARG" ]; then
    echo "Usage: impl-stamp.sh <UNIT-NNN | unit_NNN_name.md>" >&2
    exit 1
fi

cd "$PROJECT_ROOT"

# Require bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: bash 4+ required (found ${BASH_VERSION})" >&2
    exit 1
fi

# ─── Cross-platform hash command ─────────────────────────────────

if command -v sha256sum &> /dev/null; then
    hash_cmd() { sha256sum "$1" | cut -c1-16; }
else
    hash_cmd() { shasum -a 256 "$1" | cut -c1-16; }
fi

# ─── Cross-platform sed -i ───────────────────────────────────────

if [[ "$OSTYPE" == "darwin"* ]]; then
    sed_inplace() { sed -i '' "$@"; }
else
    sed_inplace() { sed -i "$@"; }
fi

# ─── Resolve unit argument ───────────────────────────────────────

resolve_unit() {
    local arg="$1"

    # Try direct basename match
    if [ -f "$UNIT_DIR/$arg" ]; then
        echo "$UNIT_DIR/$arg"
        return 0
    fi

    # Extract 3-digit number from UNIT-NNN, unit-NNN, etc.
    local num
    num=$(echo "$arg" | grep -oE '[0-9]{3}' | head -1)
    if [ -z "$num" ]; then
        echo "Error: cannot parse unit number from '$arg'" >&2
        return 1
    fi

    local matches=("$UNIT_DIR"/unit_${num}_*.md)
    if [ -f "${matches[0]}" ]; then
        echo "${matches[0]}"
        return 0
    fi

    echo "Error: no unit file found for '$arg'" >&2
    return 1
}

UNIT_FILE=$(resolve_unit "$UNIT_ARG")
UNIT_BASENAME=$(basename "$UNIT_FILE")

# ─── Compute current hash ────────────────────────────────────────

CURRENT_HASH=$(hash_cmd "$UNIT_FILE")
TODAY=$(date +%Y-%m-%d)

echo "impl-stamp: $UNIT_BASENAME"
echo "Hash: \`$CURRENT_HASH\` ($TODAY)"
echo ""

# ─── Extract implementation file paths from ## Implementation ─────

IMPL_FILES=$(awk '
    BEGIN { found = 0 }
    $0 == "## Implementation" { found = 1; next }
    found && /^#/ { match($0, /^#+/); if (RLENGTH <= 2) exit }
    found && /^- `[^`]+`/ {
        match($0, /`[^`]+`/)
        path = substr($0, RSTART+1, RLENGTH-2)
        if (path !~ /[<>]/) print path
    }
' "$UNIT_FILE")

if [ -z "$IMPL_FILES" ]; then
    echo "No implementation files listed in ## Implementation section."
    exit 0
fi

UPDATED=0
WARNED=0

# ─── Build set of listed files for orphan check ──────────────────

declare -A LISTED_FILES

# ─── Process each implementation file ─────────────────────────────

while IFS= read -r impl_path; do
    [ -z "$impl_path" ] && continue
    LISTED_FILES["$impl_path"]=1

    if [ ! -f "$PROJECT_ROOT/$impl_path" ]; then
        echo "⚠ not found  — $impl_path"
        WARNED=$((WARNED + 1))
        continue
    fi

    if grep -q "Spec-ref:.*${UNIT_BASENAME}" "$PROJECT_ROOT/$impl_path"; then
        # Update hash and date, preserving comment prefix
        sed_inplace "s|\(Spec-ref:[[:space:]]*${UNIT_BASENAME}[[:space:]]*\)\`[0-9a-f]\{16\}\`[[:space:]]*[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}|\1\`${CURRENT_HASH}\` ${TODAY}|" "$PROJECT_ROOT/$impl_path"
        echo "✓ updated    — $impl_path"
        UPDATED=$((UPDATED + 1))
    else
        echo "⚠ no Spec-ref — $impl_path"
        WARNED=$((WARNED + 1))
    fi
done <<< "$IMPL_FILES"

# ─── Scan for orphaned references ─────────────────────────────────

echo ""

ORPHAN_FILES=$(git ls-files --cached --others --exclude-standard 2>/dev/null | xargs grep -lI "Spec-ref:.*${UNIT_BASENAME}" 2>/dev/null || true)

ORPHAN_FOUND=0
if [ -n "$ORPHAN_FILES" ]; then
    while IFS= read -r orphan; do
        [ -z "$orphan" ] && continue
        if [ -z "${LISTED_FILES[$orphan]:-}" ]; then
            echo "⚠ orphan     — $orphan (has Spec-ref to $UNIT_BASENAME but not in ## Implementation)"
            WARNED=$((WARNED + 1))
            ORPHAN_FOUND=$((ORPHAN_FOUND + 1))
        fi
    done <<< "$ORPHAN_FILES"
fi

if [ "$ORPHAN_FOUND" -eq 0 ]; then
    echo "No orphaned references found."
fi

# ─── Summary ──────────────────────────────────────────────────────

echo ""
echo "Summary: $UPDATED updated, $WARNED warnings"

exit $((WARNED > 0 ? 1 : 0))
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/impl-stamp.sh"

# --- .syskit/scripts/manifest-check.sh ---
info "Creating .syskit/scripts/manifest-check.sh"
cat > ".syskit/scripts/manifest-check.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Check freshness of a snapshot against current file hashes
# Usage: manifest-check.sh <snapshot-file>
# Exit codes: 0 = all fresh, 1 = stale or deleted files found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SNAPSHOT="${1:-}"

if [ -z "$SNAPSHOT" ]; then
    echo "Usage: manifest-check.sh <snapshot-file>" >&2
    exit 1
fi

if [ ! -f "$SNAPSHOT" ]; then
    echo "Error: snapshot not found: $SNAPSHOT" >&2
    exit 1
fi

# Determine hash command (Linux vs macOS)
if command -v sha256sum &> /dev/null; then
    hash_cmd() { sha256sum "$1" | cut -c1-16; }
else
    hash_cmd() { shasum -a 256 "$1" | cut -c1-16; }
fi

STALE=0

echo "# Freshness Check"
echo ""
echo "Snapshot: $SNAPSHOT"
echo ""

while IFS='|' read -r _ file hash _; do
    file=$(echo "$file" | xargs)
    hash=$(echo "$hash" | sed 's/`//g' | xargs)

    filepath="$PROJECT_ROOT/$file"

    if [ ! -f "$filepath" ]; then
        echo "✗ deleted  — $file"
        STALE=1
    else
        current=$(hash_cmd "$filepath")
        if [ "$hash" = "$current" ]; then
            echo "✓ unchanged — $file"
        else
            echo "⚠ modified  — $file"
            STALE=1
        fi
    fi
done < <(grep '^| doc/' "$SNAPSHOT")

if [ "$STALE" -eq 0 ]; then
    echo ""
    echo "All documents are fresh."
else
    echo ""
    echo "Some documents have changed since the snapshot was taken."
fi

exit $STALE
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/manifest-check.sh"

# --- .syskit/scripts/manifest-snapshot.sh ---
info "Creating .syskit/scripts/manifest-snapshot.sh"
cat > ".syskit/scripts/manifest-snapshot.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Generate a snapshot.md capturing current SHA256 hashes of all doc files
# Usage: manifest-snapshot.sh <output-dir>
#   Snapshots all files listed in the manifest
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$PROJECT_ROOT/.syskit/manifest.md"

OUTPUT_DIR="${1:-.}"

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: output directory does not exist: $OUTPUT_DIR" >&2
    exit 1
fi

SNAPSHOT="$OUTPUT_DIR/snapshot.md"

# Determine hash command (Linux vs macOS)
if command -v sha256sum &> /dev/null; then
    hash_cmd() { sha256sum "$1" | cut -c1-16; }
else
    hash_cmd() { shasum -a 256 "$1" | cut -c1-16; }
fi

if [ ! -f "$MANIFEST" ]; then
    echo "Error: manifest not found at $MANIFEST" >&2
    echo "Run .syskit/scripts/manifest.sh first" >&2
    exit 1
fi

cat > "$SNAPSHOT" << EOF
# Document Snapshot

Captured: $(date -Iseconds)

| File | SHA256 |
|------|--------|
EOF

cd "$PROJECT_ROOT"
grep '^| doc/' "$MANIFEST" | while IFS='|' read -r _ file _ _; do
    file=$(echo "$file" | xargs)
    if [ -f "$file" ]; then
        hash=$(hash_cmd "$file")
        echo "| $file | \`$hash\` |" >> "$SNAPSHOT"
    fi
done

echo "Snapshot written: $SNAPSHOT"
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/manifest-snapshot.sh"

# --- .syskit/scripts/manifest.sh ---
info "Creating .syskit/scripts/manifest.sh"
cat > ".syskit/scripts/manifest.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Generate manifest of all specification documents with SHA256 hashes
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$PROJECT_ROOT/.syskit/manifest.md"

cd "$PROJECT_ROOT"

cat > "$MANIFEST" << 'HEADER'
# Specification Manifest

This file tracks the SHA256 hashes of all specification documents.
Used for freshness checking in impact analysis and task planning.

HEADER

echo "Generated: $(date -Iseconds)" >> "$MANIFEST"
echo "" >> "$MANIFEST"

# Function to hash files in a directory
hash_directory() {
    local dir=$1
    local title=$2
    
    echo "## $title" >> "$MANIFEST"
    echo "" >> "$MANIFEST"
    
    if [ ! -d "$dir" ]; then
        echo "*No files*" >> "$MANIFEST"
        echo "" >> "$MANIFEST"
        return
    fi
    
    local files=$(find "$dir" -name "*.md" -type f 2>/dev/null | sort)
    
    if [ -z "$files" ]; then
        echo "*No files*" >> "$MANIFEST"
        echo "" >> "$MANIFEST"
        return
    fi
    
    echo "| File | SHA256 | Modified |" >> "$MANIFEST"
    echo "|------|--------|----------|" >> "$MANIFEST"
    
    for f in $files; do
        # Get relative path from project root
        local relpath="${f#$PROJECT_ROOT/}"
        
        # Get SHA256 (compatible with both Linux and macOS)
        if command -v sha256sum &> /dev/null; then
            local hash=$(sha256sum "$f" | cut -c1-16)
        else
            local hash=$(shasum -a 256 "$f" | cut -c1-16)
        fi
        
        # Get modification date
        if [[ "$OSTYPE" == "darwin"* ]]; then
            local mod=$(stat -f "%Sm" -t "%Y-%m-%d" "$f")
        else
            local mod=$(date -r "$f" +%Y-%m-%d)
        fi
        
        echo "| $relpath | \`$hash\` | $mod |" >> "$MANIFEST"
    done
    
    echo "" >> "$MANIFEST"
}

hash_directory "doc/requirements" "Requirements"
hash_directory "doc/interfaces" "Interfaces"
hash_directory "doc/design" "Design"

echo "Manifest updated: $MANIFEST"
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/manifest.sh"

# --- .syskit/scripts/new-int.sh ---
info "Creating .syskit/scripts/new-int.sh"
cat > ".syskit/scripts/new-int.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Create a new interface document
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INT_DIR="$PROJECT_ROOT/doc/interfaces"

NAME=$1

if [ -z "$NAME" ]; then
    echo "Usage: new-int.sh <interface_name>"
    echo "Example: new-int.sh register_map"
    exit 1
fi

# Sanitize name: lowercase, replace spaces/hyphens with underscores
NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

mkdir -p "$INT_DIR"

# Find next available number
NEXT_NUM=1
for f in "$INT_DIR"/int_[0-9][0-9][0-9]_*.md; do
    if [ -f "$f" ]; then
        NUM=$(basename "$f" | sed 's/int_\([0-9]*\)_.*/\1/' | sed 's/^0*//')
        NUM=${NUM:-0}  # Default to 0 if empty
        if [ "$NUM" -ge "$NEXT_NUM" ]; then
            NEXT_NUM=$((NUM + 1))
        fi
    fi
done

NUM_PADDED=$(printf "%03d" $NEXT_NUM)
FILENAME="int_${NUM_PADDED}_${NAME}.md"
FILEPATH="$INT_DIR/$FILENAME"
ID="INT-${NUM_PADDED}"

if [ -f "$FILEPATH" ]; then
    echo "Error: $FILEPATH already exists"
    exit 1
fi

cat > "$FILEPATH" << EOF
# $ID: $(echo "$NAME" | tr '_' ' ' | sed 's/\b\(.\)/\u\1/g')

## Type

Internal | External Standard | External Service

## External Specification

<!-- For external interfaces only -->
- **Standard:** <name and version>
- **Reference:** <URL or document reference>

## Parties

- **Provider:** UNIT-NNN (<unit name>) | External
- **Consumer:** UNIT-NNN (<unit name>)

## Referenced By

- REQ-NNN (<requirement name>)

## Specification

<!-- For internal interfaces, define the specification here -->
<!-- For external interfaces, document your usage subset -->

### Overview

<Brief description of the interface>

### Details

<Detailed specification>

## Constraints

<Any constraints or limitations on usage>

## Notes

<Additional context>
EOF

echo "Created: $FILEPATH"
echo "ID: $ID"
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/new-int.sh"

# --- .syskit/scripts/new-req.sh ---
info "Creating .syskit/scripts/new-req.sh"
cat > ".syskit/scripts/new-req.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Create a new requirement document
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REQ_DIR="$PROJECT_ROOT/doc/requirements"

PARENT=""
if [ "${1:-}" = "--parent" ]; then
    PARENT="$2"
    shift 2
fi

NAME="${1:-}"

if [ -z "$NAME" ]; then
    echo "Usage: new-req.sh [--parent REQ-NNN[.NN...]] <requirement_name>"
    echo "Example: new-req.sh spi_interface"
    echo "Example: new-req.sh --parent REQ-001 spi_voltage_levels"
    echo "Example: new-req.sh --parent REQ-001.03 spi_clock_timing"
    exit 1
fi

# Sanitize name: lowercase, replace spaces/hyphens with underscores
NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

mkdir -p "$REQ_DIR"

if [ -n "$PARENT" ]; then
    # ─── Child requirement: REQ-NNN.NN under parent ──────────────

    # Extract numeric prefix from parent ID (e.g., REQ-004 → 004, REQ-004.01 → 004.01)
    PARENT_NUM=$(echo "$PARENT" | sed 's/^REQ-//')

    if ! [[ "$PARENT_NUM" =~ ^[0-9]{3}(\.[0-9]{2})*$ ]]; then
        echo "Error: invalid parent ID '$PARENT' (expected REQ-NNN or REQ-NNN.NN[.NN...])" >&2
        exit 1
    fi

    # Warn if parent file doesn't exist
    PARENT_FILE=$(find "$REQ_DIR" -maxdepth 1 -name "req_${PARENT_NUM}_*.md" -print -quit 2>/dev/null)
    if [ -z "$PARENT_FILE" ]; then
        echo "Warning: parent $PARENT has no matching file in $REQ_DIR" >&2
    fi

    # Find next available child number under this parent
    NEXT_CHILD=1
    for f in "$REQ_DIR"/req_${PARENT_NUM}.[0-9][0-9]_*.md; do
        if [ -f "$f" ]; then
            CHILD_NUM=$(basename "$f" | sed "s/req_${PARENT_NUM}\.\([0-9][0-9]\)_.*/\1/" | sed 's/^0*//')
            CHILD_NUM=${CHILD_NUM:-0}
            if [ "$CHILD_NUM" -ge "$NEXT_CHILD" ]; then
                NEXT_CHILD=$((CHILD_NUM + 1))
            fi
        fi
    done

    CHILD_PADDED=$(printf "%02d" $NEXT_CHILD)
    NUM_PART="${PARENT_NUM}.${CHILD_PADDED}"
    FILENAME="req_${NUM_PART}_${NAME}.md"
    FILEPATH="$REQ_DIR/$FILENAME"
    ID="REQ-${NUM_PART}"
else
    # ─── Top-level requirement: REQ-NNN ──────────────────────────

    NEXT_NUM=1
    for f in "$REQ_DIR"/req_[0-9][0-9][0-9]_*.md; do
        if [ -f "$f" ]; then
            NUM=$(basename "$f" | sed 's/req_\([0-9]*\)_.*/\1/' | sed 's/^0*//')
            NUM=${NUM:-0}  # Default to 0 if empty
            if [ "$NUM" -ge "$NEXT_NUM" ]; then
                NEXT_NUM=$((NUM + 1))
            fi
        fi
    done

    NUM_PADDED=$(printf "%03d" $NEXT_NUM)
    FILENAME="req_${NUM_PADDED}_${NAME}.md"
    FILEPATH="$REQ_DIR/$FILENAME"
    ID="REQ-${NUM_PADDED}"
fi

if [ -f "$FILEPATH" ]; then
    echo "Error: $FILEPATH already exists"
    exit 1
fi

# Set parent display: use provided parent, or "None" for top-level
PARENT_DISPLAY="${PARENT:-None}"

cat > "$FILEPATH" << EOF
# $ID: $(echo "$NAME" | tr '_' ' ' | sed 's/\b\(.\)/\u\1/g')

## Classification

- **Priority:** Essential | Important | Nice-to-have
- **Stability:** Stable | Evolving | Volatile
- **Verification:** Test | Analysis | Inspection | Demonstration

## Requirement

When [condition/trigger], the system SHALL [observable behavior/response].

<!-- Format: When [condition], the system SHALL/SHOULD/MAY [behavior].
     Each requirement must have a testable trigger and observable outcome.
     Describe capabilities/behaviors, not data layout or encoding.
     For struct fields, byte formats, protocols → use an interface (INT-NNN). -->

## Rationale

<Why this requirement exists>

## Parent Requirements

- ${PARENT_DISPLAY}

## Allocated To

- UNIT-NNN (<unit name>)

## Interfaces

- INT-NNN (<interface name>)

## Verification Method

<How this requirement will be verified>

## Notes

<Additional context>
EOF

echo "Created: $FILEPATH"
echo "ID: $ID"
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/new-req.sh"

# --- .syskit/scripts/new-unit.sh ---
info "Creating .syskit/scripts/new-unit.sh"
cat > ".syskit/scripts/new-unit.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Create a new design unit document
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UNIT_DIR="$PROJECT_ROOT/doc/design"

NAME=$1

if [ -z "$NAME" ]; then
    echo "Usage: new-unit.sh <unit_name>"
    echo "Example: new-unit.sh spi_slave"
    exit 1
fi

# Sanitize name: lowercase, replace spaces/hyphens with underscores
NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

mkdir -p "$UNIT_DIR"

# Find next available number
NEXT_NUM=1
for f in "$UNIT_DIR"/unit_[0-9][0-9][0-9]_*.md; do
    if [ -f "$f" ]; then
        NUM=$(basename "$f" | sed 's/unit_\([0-9]*\)_.*/\1/' | sed 's/^0*//')
        NUM=${NUM:-0}  # Default to 0 if empty
        if [ "$NUM" -ge "$NEXT_NUM" ]; then
            NEXT_NUM=$((NUM + 1))
        fi
    fi
done

NUM_PADDED=$(printf "%03d" $NEXT_NUM)
FILENAME="unit_${NUM_PADDED}_${NAME}.md"
FILEPATH="$UNIT_DIR/$FILENAME"
ID="UNIT-${NUM_PADDED}"

if [ -f "$FILEPATH" ]; then
    echo "Error: $FILEPATH already exists"
    exit 1
fi

cat > "$FILEPATH" << EOF
# $ID: $(echo "$NAME" | tr '_' ' ' | sed 's/\b\(.\)/\u\1/g')

## Purpose

<What this unit does and why it exists>

## Implements Requirements

- REQ-NNN (<requirement name>)

## Interfaces

### Provides

- INT-NNN (<interface name>)

### Consumes

- INT-NNN (<interface name>)

### Internal Interfaces

- Connects to UNIT-NNN via <description>

## Design Description

<How this unit works>

### Inputs

<Input signals, parameters, or data>

### Outputs

<Output signals, parameters, or data>

### Internal State

<Any internal state maintained>

### Algorithm / Behavior

<Description of the unit's behavior>

## Implementation

- \`<filepath>\`: <description>

## Verification

- \`<test filepath>\`: <what it tests>

## Design Notes

<Additional design considerations, tradeoffs, alternatives considered>
EOF

echo "Created: $FILEPATH"
echo "ID: $ID"
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/new-unit.sh"

# --- .syskit/scripts/toc-update.sh ---
info "Creating .syskit/scripts/toc-update.sh"
cat > ".syskit/scripts/toc-update.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Update the Table of Contents in each doc/*/README.md
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Explicit ordering for non-numbered framework files per directory.
# Files listed here appear first in the TOC, in this order.
# Any non-numbered file NOT listed gets appended alphabetically after these.
framework_order() {
    case "$1" in
        *requirements) echo "states_and_modes.md quality_metrics.md" ;;
        *design)       echo "design_decisions.md concept_of_execution.md" ;;
        *)             echo "" ;;
    esac
}

# Update TOC in a single README.md
# Scans sibling .md files, extracts H1 headings, writes a linked list
# Ordering: explicitly ordered framework files, then remaining framework
# files alphabetically, then numbered spec files alphabetically.
update_toc() {
    local dir=$1
    local readme="$dir/README.md"

    if [ ! -f "$readme" ]; then
        return
    fi

    # Check for TOC markers
    if ! grep -q '<!-- TOC-START -->' "$readme"; then
        return
    fi

    local explicit_order
    explicit_order=$(framework_order "$dir")

    # Collect entries into two groups: framework (non-numbered) and numbered
    local numbered_entries=""
    local framework_entries=""

    for f in $(find "$dir" -maxdepth 1 -name "*.md" -type f | LC_COLLATE=C sort); do
        local base=$(basename "$f")

        # Skip README itself and 000 templates
        case "$base" in
            README.md|*_000_template.md) continue ;;
        esac

        # Extract H1 heading (first line starting with "# ")
        local heading=$(grep -m1 '^# ' "$f" | sed 's/^# //')
        if [ -z "$heading" ]; then
            heading="$base"
        fi

        local entry="${base}|${heading}\n"

        # Classify: numbered spec files vs framework files
        case "$base" in
            req_[0-9][0-9][0-9]*.md | unit_[0-9][0-9][0-9]*.md | int_[0-9][0-9][0-9]*.md)
                numbered_entries="${numbered_entries}${entry}"
                ;;
            *)
                framework_entries="${framework_entries}${entry}"
                ;;
        esac
    done

    # Order framework entries: explicit order first, then alphabetical remainder
    local ordered_framework=""

    for explicit_file in $explicit_order; do
        local match
        match=$(printf "$framework_entries" | grep "^${explicit_file}|" || true)
        if [ -n "$match" ]; then
            ordered_framework="${ordered_framework}${match}\n"
        fi
    done

    # Append any framework files not in the explicit order list
    if [ -n "$framework_entries" ]; then
        while IFS='|' read -r base heading; do
            [ -z "$base" ] && continue
            local already_listed=false
            for explicit_file in $explicit_order; do
                if [ "$base" = "$explicit_file" ]; then
                    already_listed=true
                    break
                fi
            done
            if [ "$already_listed" = false ]; then
                ordered_framework="${ordered_framework}${base}|${heading}\n"
            fi
        done < <(printf "$framework_entries")
    fi

    # Combine: framework first, then numbered
    local all_entries="${ordered_framework}${numbered_entries}"

    # Build replacement block
    local toc_block=""
    if [ -z "$all_entries" ]; then
        toc_block="*No documents yet.*"
    else
        while IFS='|' read -r base heading; do
            [ -z "$base" ] && continue
            toc_block="${toc_block}- [${heading}](${base})\n"
        done < <(printf "$all_entries")
    fi

    # Replace content between TOC markers
    # Strategy: print before START, print new TOC, skip until END, print after END
    local tmp="${readme}.tmp"
    awk -v toc="$toc_block" '
    /<!-- TOC-START -->/ {
        print
        # Print the toc content using printf-style interpretation
        n = split(toc, lines, "\\n")
        for (i = 1; i <= n; i++) {
            if (lines[i] != "") print lines[i]
        }
        skip = 1
        next
    }
    /<!-- TOC-END -->/ {
        skip = 0
        print
        next
    }
    !skip { print }
    ' "$readme" > "$tmp"

    mv "$tmp" "$readme"
}

update_toc "doc/requirements"
update_toc "doc/interfaces"
update_toc "doc/design"

echo "TOC updated in doc/*/README.md"
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/toc-update.sh"

# --- .syskit/scripts/trace-sync.sh ---
info "Creating .syskit/scripts/trace-sync.sh"
cat > ".syskit/scripts/trace-sync.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Check and optionally fix bidirectional cross-references between spec documents
# Usage: trace-sync.sh [--fix]
# Exit codes: 0 = all consistent, 1 = issues found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

REQ_DIR="$PROJECT_ROOT/doc/requirements"
INT_DIR="$PROJECT_ROOT/doc/interfaces"
UNIT_DIR="$PROJECT_ROOT/doc/design"

FIX_MODE=false
[ "${1:-}" = "--fix" ] && FIX_MODE=true

# Require bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: bash 4+ required (found ${BASH_VERSION})" >&2
    exit 1
fi

# ─── ID Map ────────────────────────────────────────────────────────

declare -A ID_TO_FILE    # ID -> full file path
declare -A ID_TO_NAME    # ID -> human-readable name from H1
declare -A ALL_IDS       # ID -> 1

# Regex pattern for hierarchical requirement IDs: REQ-NNN or REQ-NNN.NN[.NN...]
REQ_PAT='REQ-[0-9]{3}(\.[0-9]{2})*'

build_id_map() {
    local tag dir prefix entry base num id name
    # Scan INT and UNIT (flat numbering)
    for entry in "int:$INT_DIR:INT" "unit:$UNIT_DIR:UNIT"; do
        IFS=':' read -r tag dir prefix <<< "$entry"
        [ -d "$dir" ] || continue
        for f in "$dir"/${tag}_[0-9][0-9][0-9]_*.md; do
            [ -f "$f" ] || continue
            base=$(basename "$f")
            [[ "$base" == *_000_template* ]] && continue
            num=$(echo "$base" | sed "s/${tag}_\([0-9][0-9][0-9]\)_.*/\1/")
            id="${prefix}-${num}"
            ID_TO_FILE["$id"]="$f"
            ALL_IDS["$id"]=1
            name=$(head -1 "$f" | sed "s/^# *${prefix}-${num}: *//")
            ID_TO_NAME["$id"]="$name"
        done
    done

    # Scan REQ (supports hierarchical numbering: REQ-001, REQ-001.05, etc.)
    if [ -d "$REQ_DIR" ]; then
        for f in "$REQ_DIR"/req_*.md; do
            [ -f "$f" ] || continue
            base=$(basename "$f")
            [[ "$base" == *_000_template* ]] && continue
            # Match req_NNN_name.md or req_NNN.NN[.NN...]_name.md
            if [[ "$base" =~ ^req_([0-9]{3}(\.[0-9]{2})*)_.+\.md$ ]]; then
                num="${BASH_REMATCH[1]}"
                id="REQ-${num}"
                ID_TO_FILE["$id"]="$f"
                ALL_IDS["$id"]=1
                name=$(head -1 "$f" | sed "s/^# *REQ-${num}: *//")
                ID_TO_NAME["$id"]="$name"
            fi
        done
    fi
}

# ─── Reference Storage ─────────────────────────────────────────────
# REFS["type:SOURCE_ID"] = "TARGET1 TARGET2 ..."

declare -A REFS

add_ref() { # <type> <source> <target>
    local key="$1:$2"
    REFS["$key"]="${REFS[$key]:-}${REFS[$key]:+ }$3"
}

has_ref() { # <type> <source> <target> -> exit code
    [[ " ${REFS[$1:$2]:-} " == *" $3 "* ]]
}

# ─── Section Parser ────────────────────────────────────────────────

# Extract text lines within a section (between heading and next same/higher-level heading)
section_lines() { # <file> <heading> <level>
    awk -v section="$2" -v level="$3" '
        BEGIN { found = 0 }
        $0 == section { found = 1; next }
        found && /^#/ { match($0, /^#+/); if (RLENGTH <= level) exit }
        found { print }
    ' "$1"
}

# Extract unique IDs matching a pattern from a section
section_ids() { # <file> <heading> <level> <id_pattern>
    section_lines "$1" "$2" "$3" | grep -oE "$4" | sort -u || true
}

# ─── Parse All Documents ──────────────────────────────────────────

parse_all() {
    local id file x parties
    for id in "${!ALL_IDS[@]}"; do
        file="${ID_TO_FILE[$id]}"
        case "$id" in
            REQ-*)
                for x in $(section_ids "$file" "## Allocated To" 2 "UNIT-[0-9]{3}"); do
                    add_ref req_alloc "$id" "$x"
                done
                for x in $(section_ids "$file" "## Interfaces" 2 "INT-[0-9]{3}"); do
                    add_ref req_iface "$id" "$x"
                done
                ;;
            UNIT-*)
                for x in $(section_ids "$file" "## Implements Requirements" 2 "$REQ_PAT"); do
                    add_ref unit_impl "$id" "$x"
                done
                for x in $(section_ids "$file" "### Provides" 3 "INT-[0-9]{3}"); do
                    add_ref unit_prov "$id" "$x"
                done
                for x in $(section_ids "$file" "### Consumes" 3 "INT-[0-9]{3}"); do
                    add_ref unit_cons "$id" "$x"
                done
                ;;
            INT-*)
                parties=$(section_lines "$file" "## Parties" 2)
                for x in $(echo "$parties" | grep -i 'Provider' | grep -oE 'UNIT-[0-9]{3}' || true); do
                    add_ref int_prov "$id" "$x"
                done
                for x in $(echo "$parties" | grep -i 'Consumer' | grep -oE 'UNIT-[0-9]{3}' || true); do
                    add_ref int_cons "$id" "$x"
                done
                for x in $(section_ids "$file" "## Referenced By" 2 "$REQ_PAT"); do
                    add_ref int_refby "$id" "$x"
                done
                ;;
        esac
    done
}

# ─── Insertion Helper ─────────────────────────────────────────────

# Insert a line after the last list item in a section (or after the heading if none)
insert_in_section() { # <file> <heading> <level> <new_line>
    local file="$1" heading="$2" level="$3" new_line="$4"

    # Find the line number to insert after
    local insert_after
    insert_after=$(awk -v section="$heading" -v level="$level" '
        BEGIN { in_sec = 0; last_item = 0; sec_line = 0 }
        $0 == section { in_sec = 1; sec_line = NR; next }
        in_sec && /^#/ { match($0, /^#+/); if (RLENGTH <= level) in_sec = 0 }
        in_sec && /^- / { last_item = NR }
        END {
            if (last_item > 0) print last_item
            else if (sec_line > 0) print sec_line
            else print 0
        }
    ' "$file")

    if [ "$insert_after" -eq 0 ]; then
        return 1
    fi

    # Insert using awk (cross-platform, avoids sed -i differences)
    local temp
    temp=$(mktemp)
    awk -v after="$insert_after" -v newline="$new_line" '
        { print }
        NR == after { print newline }
    ' "$file" > "$temp"
    mv "$temp" "$file"
}

# ─── Check & Fix ──────────────────────────────────────────────────

MISSING=0
BROKEN=0
ORPHANS=0
FIXED=0

check_broken() {
    local key source target seen=""
    for key in "${!REFS[@]}"; do
        source="${key#*:}"
        for target in ${REFS[$key]}; do
            if [ -z "${ALL_IDS[$target]:-}" ]; then
                # Deduplicate: same source->target may appear via different ref types
                local pair="$source->$target"
                [[ "$seen" == *"$pair"* ]] && continue
                seen="$seen $pair"
                echo "BROKEN   $source references $target — no matching file found"
                BROKEN=$((BROKEN + 1))
            fi
        done
    done
}

# Check one direction of a bidirectional relationship.
# For each ref fwd:A->B, verify back:B->A exists.
check_pair() { # <fwd_type> <back_type> <fwd_label> <back_label> <back_heading> <back_level> <format>
    local fwd="$1" back="$2" fwd_label="$3" back_label="$4"
    local back_heading="$5" back_level="$6" fmt="$7"
    local key src tgt tgt_base src_name line

    for key in "${!REFS[@]}"; do
        [[ "$key" == "${fwd}:"* ]] || continue
        src="${key#*:}"
        for tgt in ${REFS[$key]}; do
            # Skip broken references (reported separately)
            [ -z "${ALL_IDS[$tgt]:-}" ] && continue
            # Skip if back-reference already exists
            has_ref "$back" "$tgt" "$src" && continue

            tgt_base=$(basename "${ID_TO_FILE[$tgt]}")
            src_name="${ID_TO_NAME[$src]:-}"

            if $FIX_MODE; then
                case "$fmt" in
                    list)     line="- ${src} (${src_name})" ;;
                    provider) line="- **Provider:** ${src} (${src_name})" ;;
                    consumer) line="- **Consumer:** ${src} (${src_name})" ;;
                esac
                if insert_in_section "${ID_TO_FILE[$tgt]}" "$back_heading" "$back_level" "$line"; then
                    echo "FIXED    ${tgt_base}: added ${src} to \"${back_label}\""
                    FIXED=$((FIXED + 1))
                    add_ref "$back" "$tgt" "$src"
                else
                    echo "SKIPPED  ${tgt_base}: \"${back_label}\" section not found"
                    MISSING=$((MISSING + 1))
                fi
            else
                echo "MISSING  ${tgt_base} \"${back_label}\" lacks ${src}"
                echo "  reason: ${src} \"${fwd_label}\" references ${tgt}"
                MISSING=$((MISSING + 1))
            fi
        done
    done
}

check_consistency() {
    # REQ.AllocatedTo <-> UNIT.ImplementsReq
    check_pair req_alloc unit_impl \
        "Allocated To" "Implements Requirements" \
        "## Implements Requirements" 2 list
    check_pair unit_impl req_alloc \
        "Implements Requirements" "Allocated To" \
        "## Allocated To" 2 list

    # REQ.Interfaces <-> INT.ReferencedBy
    check_pair req_iface int_refby \
        "Interfaces" "Referenced By" \
        "## Referenced By" 2 list
    check_pair int_refby req_iface \
        "Referenced By" "Interfaces" \
        "## Interfaces" 2 list

    # UNIT.Provides <-> INT.Provider
    check_pair unit_prov int_prov \
        "Provides" "Parties (Provider)" \
        "## Parties" 2 provider
    check_pair int_prov unit_prov \
        "Parties (Provider)" "Provides" \
        "### Provides" 3 list

    # UNIT.Consumes <-> INT.Consumer
    check_pair unit_cons int_cons \
        "Consumes" "Parties (Consumer)" \
        "## Parties" 2 consumer
    check_pair int_cons unit_cons \
        "Parties (Consumer)" "Consumes" \
        "### Consumes" 3 list
}

check_orphans() {
    local id found key target
    for id in "${!ALL_IDS[@]}"; do
        found=false
        for key in "${!REFS[@]}"; do
            for target in ${REFS[$key]}; do
                if [ "$target" = "$id" ]; then
                    found=true
                    break 2
                fi
            done
        done
        if ! $found; then
            echo "ORPHAN   ${id} (${ID_TO_NAME[$id]:-}) — not referenced by any document"
            ORPHANS=$((ORPHANS + 1))
        fi
    done
}

# ─── Main ─────────────────────────────────────────────────────────

build_id_map

REQ_N=0 INT_N=0 UNIT_N=0
for id in "${!ALL_IDS[@]}"; do
    case "$id" in
        REQ-*)  REQ_N=$((REQ_N + 1)) ;;
        INT-*)  INT_N=$((INT_N + 1)) ;;
        UNIT-*) UNIT_N=$((UNIT_N + 1)) ;;
    esac
done

echo "# Traceability Sync$($FIX_MODE && echo ' (--fix)')"
echo ""
echo "Scanned: ${REQ_N} requirements, ${INT_N} interfaces, ${UNIT_N} design units"
echo ""

if [ $((REQ_N + INT_N + UNIT_N)) -eq 0 ]; then
    echo "No specification documents found in doc/."
    exit 0
fi

parse_all
check_broken
check_consistency
check_orphans

echo ""
TOTAL=$((MISSING + BROKEN + ORPHANS))

if $FIX_MODE; then
    echo "Summary: ${FIXED} fixed, ${TOTAL} remaining issues"
else
    echo "Summary: ${MISSING} missing, ${BROKEN} broken, ${ORPHANS} orphans"
fi

if [ "$TOTAL" -eq 0 ]; then
    echo "All cross-references are consistent."
fi

exit $((TOTAL > 0 ? 1 : 0))
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/trace-sync.sh"

# --- .syskit/prompts/impact-analysis.md ---
info "Creating .syskit/prompts/impact-analysis.md"
cat > ".syskit/prompts/impact-analysis.md" << '__SYSKIT_TEMPLATE_END__'
# Impact Analysis — Subagent Instructions

You are analyzing the impact of a proposed change on specification documents.

## Proposed Change

{{PROPOSED_CHANGE}}

## Instructions

1. Read ALL markdown files in these directories:
   - `doc/requirements/`
   - `doc/interfaces/`
   - `doc/design/`

   Skip any files with `_000_template` in the name.

2. For each document, extract:
   - The document ID (from the H1 heading, e.g., "REQ-001", "INT-003", "UNIT-007")
   - The document title (from the H1 heading after the ID)
   - All cross-references to other documents (REQ-NNN, INT-NNN, UNIT-NNN mentions)
   - A brief summary of what the document specifies (1-2 sentences)

3. Analyze each document against the proposed change. Categorize as:
   - **DIRECT**: The document itself describes something being changed
   - **INTERFACE**: The document defines or uses an interface affected by the change
   - **DEPENDENT**: The document depends on something being changed (via REQ/INT/UNIT references to a DIRECT or INTERFACE document)
   - **UNAFFECTED**: The document is not impacted

   When tracing dependencies:
   - If a requirement is DIRECT, check which design units have it in "Implements Requirements" (those are DEPENDENT)
   - If a requirement is DIRECT, check which interfaces it lists under "Interfaces" (those are INTERFACE)
   - If an interface is DIRECT or INTERFACE, check which units list it under "Provides" or "Consumes" (those are DEPENDENT)
   - If a design unit is DIRECT, check which requirements it implements (review for DEPENDENT impact)

4. Write your complete analysis to `{{ANALYSIS_FOLDER}}/impact.md` in this format:

   ```markdown
   # Impact Analysis: <brief change summary>

   Created: <timestamp>
   Status: Pending Review

   ## Proposed Change

   <detailed description of the change>

   ## Direct Impacts

   ### <filename>
   - **ID:** <REQ/INT/UNIT-NNN>
   - **Title:** <document title>
   - **Impact:** <what specifically is affected, 1-2 sentences>
   - **Action Required:** <modify/review/no change>
   - **Key References:** <cross-referenced IDs found in this document>

   ## Interface Impacts

   ### <filename>
   - **ID:** <INT-NNN>
   - **Title:** <document title>
   - **Impact:** <what specifically is affected>
   - **Consumers:** <UNIT-NNN that consume this interface>
   - **Providers:** <UNIT-NNN that provide this interface>
   - **Action Required:** <modify/review/no change>

   ## Dependent Impacts

   ### <filename>
   - **ID:** <REQ/INT/UNIT-NNN>
   - **Title:** <document title>
   - **Dependency:** <what it depends on that is changing, with specific ID>
   - **Impact:** <what specifically is affected>
   - **Action Required:** <modify/review/no change>

   ## Unaffected Documents

   | Document | ID | Reason Unaffected |
   |----------|-----|-------------------|
   | <filename> | <ID> | <brief reason> |

   ## Summary

   - **Total Documents:** <n>
   - **Directly Affected:** <n>
   - **Interface Affected:** <n>
   - **Dependently Affected:** <n>
   - **Unaffected:** <n>

   ## Recommended Next Steps

   1. <first action>
   2. <second action>
   ```

   If a category has no documents, include the heading with "None." underneath.

5. After writing the file, return ONLY this compact summary (nothing else):

   IMPACT_SUMMARY_START
   Total: <n> documents analyzed
   Direct: <n> — <comma-separated filenames>
   Interface: <n> — <comma-separated filenames>
   Dependent: <n> — <comma-separated filenames>
   Unaffected: <n>
   Written to: {{ANALYSIS_FOLDER}}/impact.md
   IMPACT_SUMMARY_END
__SYSKIT_TEMPLATE_END__

# --- .syskit/prompts/implement-task.md ---
info "Creating .syskit/prompts/implement-task.md"
cat > ".syskit/prompts/implement-task.md" << '__SYSKIT_TEMPLATE_END__'
# Implement Task — Subagent Instructions

You are implementing a single task from a syskit implementation plan.

## Your Assignment

- **Task file:** `{{TASK_FILE}}`
- **Task folder:** `{{TASK_FOLDER}}`

## Instructions

### 1. Read the Task

Read your task file at `{{TASK_FILE}}`. Extract:

- The objective
- Files to modify and files to create
- Implementation steps
- Verification criteria
- Specification references (REQ-NNN, INT-NNN, UNIT-NNN)

### 2. Read Referenced Files

Read all files listed in:

- **"Files to Modify"** — the source files you will change
- **"Specification References"** — the spec documents that define the required behavior

Read each file from disk. Understand what the specification requires and what the current implementation looks like.

### 3. Implement

Follow the task's implementation steps:

1. Make the changes described in the task
2. Edit files directly — do not write to a staging folder
3. Ensure changes align with the referenced specifications
4. When creating new source files that implement a design unit, add a placeholder Spec-ref comment:
   ```
   // Spec-ref: unit_NNN_name.md `0000000000000000` 1970-01-01
   ```
   (The hash will be updated by `impl-stamp.sh` after you finish.)

### 4. Verify

Work through the task's verification checklist:

1. For each verification criterion, confirm it is met
2. If a criterion cannot be verified, note why
3. Run any specified tests or build commands

### 5. Update Task Status

Edit the task file to update its status:

```markdown
Status: Complete
Completed: {{TIMESTAMP}}
```

Add a completion summary at the end of the task file:

```markdown
## Completion Notes

<What was actually done, any deviations from plan>

## Verification Results

- [x] <criterion> — <result>
- [x] <criterion> — <result>
```

### 6. Return Summary

After completing all steps, return ONLY this compact response (nothing else):

```
IMPLEMENT_SUMMARY_START
Task: <number> — <name>
Files modified: <n> — <comma-separated paths>
Files created: <n> — <comma-separated paths>
Verification: <passed>/<total> criteria passed
Failed criteria: <list any failures, or "None">
Issues: <any issues encountered, or "None">
IMPLEMENT_SUMMARY_END
```
__SYSKIT_TEMPLATE_END__

# --- .syskit/prompts/plan-extract.md ---
info "Creating .syskit/prompts/plan-extract.md"
cat > ".syskit/prompts/plan-extract.md" << '__SYSKIT_TEMPLATE_END__'
# Plan Extraction — Subagent Instructions

You are extracting implementation scope from approved specification changes.

## Instructions

1. Read the change summary from: `{{ANALYSIS_FOLDER}}/proposed_changes.md`

2. Run `git diff doc/` to see the exact specification changes that were applied.

3. Read all design unit documents (`doc/design/unit_*.md`) to understand implementation structure. Focus especially on:
   - The `## Implementation` section (lists source files)
   - The `## Implements Requirements` section (links to REQ-NNN)
   - The `## Provides` and `## Consumes` sections (links to INT-NNN)

4. For each specification change, identify:
   - Which source files need modification (from design unit Implementation sections)
   - Which test files need modification or creation
   - Dependencies between changes (what must be done first)
   - How to verify the change was implemented correctly

5. Create the task folder: `{{TASK_FOLDER}}`

6. Write `plan.md` to the task folder:

   ```markdown
   # Implementation Plan: <change name>

   Based on: ../../.syskit/analysis/<folder>/proposed_changes.md
   Created: <timestamp>
   Status: In Progress

   ## Overview

   <Brief description of what is being implemented>

   ## Specification Changes Applied

   | Document | Change Type | Summary |
   |----------|-------------|---------|
   | <doc> | Modified | <summary> |

   ## Implementation Strategy

   <High-level approach to implementing these changes>

   ## Task Sequence

   | # | Task | Dependencies | Est. Effort |
   |---|------|--------------|-------------|
   | 1 | <task name> | None | <small/medium/large> |
   | 2 | <task name> | Task 1 | <effort> |

   ## Verification Approach

   <How we will verify the implementation meets the specifications>

   ## Risks and Considerations

   - <risk or consideration>
   ```

7. Write individual task files `task_NNN_<name>.md` to the task folder:

   ```markdown
   # Task NNN: <task name>

   Status: Pending
   Dependencies: <list or "None">
   Specification References: <REQ-NNN, INT-NNN, UNIT-NNN>

   ## Objective

   <What this task accomplishes>

   ## Files to Modify

   - `<filepath>`: <what changes>

   ## Files to Create

   - `<filepath>`: <purpose>

   ## Implementation Steps

   1. <step>
   2. <step>
   3. <step>

   ## Verification

   - [ ] <verification criterion>
   - [ ] <verification criterion>

   ## Notes

   <Any additional context or considerations>
   ```

8. After writing all files, return ONLY this compact summary (nothing else):

   PLAN_SUMMARY_START
   Task folder: <path to task folder>
   Tasks created: <n>
   Task sequence:
   1. <task name> (deps: None)
   2. <task name> (deps: Task 1)
   ...
   Source files to modify: <n>
   Source files to create: <n>
   Risks: <n>
   PLAN_SUMMARY_END
__SYSKIT_TEMPLATE_END__

# --- .syskit/prompts/propose-chunk.md ---
info "Creating .syskit/prompts/propose-chunk.md"
cat > ".syskit/prompts/propose-chunk.md" << '__SYSKIT_TEMPLATE_END__'
# Propose Changes (Chunk) — Subagent Instructions

You are drafting and applying proposed specification changes for a subset of affected documents.

## Proposed Change

{{PROPOSED_CHANGE}}

## Your Assigned Documents

{{ASSIGNED_FILES}}

## Instructions

1. Read the impact analysis from: `{{ANALYSIS_FOLDER}}/impact.md`

2. Read ONLY the documents assigned to you (listed above) from the `doc/` directories.

3. For each assigned document, **edit the file directly** with the proposed changes:
   - Make the specific modifications needed to address the proposed change
   - Ensure all cross-references (REQ-NNN, INT-NNN, UNIT-NNN) remain consistent
   - For requirement documents, ensure every requirement uses the condition/response pattern: "When [condition], the system SHALL [observable behavior]."

4. While editing, validate each requirement you modify or create:
   - **Format:** Must use condition/response pattern. If it lacks a trigger condition, add one.
   - **Appropriate Level:** If it specifies data layout, register fields, byte encoding, packet structure, or wire protocol details, flag this — that detail belongs in an interface document.
   - **Singular:** If it addresses multiple capabilities, split it into separate requirements.
   - **Verifiable:** The condition must define a clear test setup and the behavior a clear pass criterion.

5. Write a chunk summary to `{{ANALYSIS_FOLDER}}/chunk_{{CHUNK_NUMBER}}.md` in this format:

   ```markdown
   ## Document: <filename>

   ### Rationale

   <why this change is needed>

   ### Changes Made

   <brief description of what was modified — the actual diff is in git>

   ### Ripple Effects

   - <any effects on other documents>

   ---

   (repeat for each assigned document)
   ```

6. After editing all assigned documents and writing the chunk summary, return ONLY this compact response (nothing else):

   CHUNK_SUMMARY_START
   Chunk: {{CHUNK_NUMBER}}
   Documents edited: <n>
   Files: <comma-separated filenames>
   Quality warnings: <n> (<brief list or "None">)
   Written to: {{ANALYSIS_FOLDER}}/chunk_{{CHUNK_NUMBER}}.md
   CHUNK_SUMMARY_END
__SYSKIT_TEMPLATE_END__

# --- .syskit/prompts/propose-single.md ---
info "Creating .syskit/prompts/propose-single.md"
cat > ".syskit/prompts/propose-single.md" << '__SYSKIT_TEMPLATE_END__'
# Propose Changes (Single) — Subagent Instructions

You are drafting and applying proposed specification changes based on a completed impact analysis.

## Proposed Change

{{PROPOSED_CHANGE}}

## Instructions

1. Read the impact analysis from: `{{ANALYSIS_FOLDER}}/impact.md`

2. Read each document listed as affected (DIRECT, INTERFACE, or DEPENDENT with Action Required of "modify" or "review"). Read them from the `doc/` directories.

3. For each affected document, **edit the file directly** with the proposed changes:
   - Make the specific modifications needed to address the proposed change
   - Ensure all cross-references (REQ-NNN, INT-NNN, UNIT-NNN) remain consistent
   - For requirement documents, ensure every requirement uses the condition/response pattern: "When [condition], the system SHALL [observable behavior]."

4. While editing, validate each requirement you modify or create:
   - **Format:** Must use condition/response pattern. If it lacks a trigger condition, add one.
   - **Appropriate Level:** If it specifies data layout, register fields, byte encoding, packet structure, or wire protocol details, flag this — that detail belongs in an interface document.
   - **Singular:** If it addresses multiple capabilities, split it into separate requirements.
   - **Verifiable:** The condition must define a clear test setup and the behavior a clear pass criterion.

5. Write a change summary to `{{ANALYSIS_FOLDER}}/proposed_changes.md` in this format:

   ```markdown
   # Proposed Changes: <change name>

   Based on: impact.md
   Created: <timestamp>
   Status: Pending Approval

   ## Change Summary

   | Document | Type | Change Description |
   |----------|------|-------------------|
   | <filename> | Modify | <brief description> |

   ## Document: <filename>

   ### Rationale

   <why this change is needed>

   ### Changes Made

   <brief description of what was modified — the actual diff is in git>

   ### Ripple Effects

   - <any effects on other documents>

   ---

   (repeat for each affected document)

   ## Quality Warnings

   <list any requirement quality issues found, or "None.">
   ```

6. After editing all documents and writing the summary, return ONLY this compact response (nothing else):

   PROPOSE_SUMMARY_START
   Documents edited: <n>
   Files: <comma-separated filenames>
   Quality warnings: <n> (<brief list or "None">)
   Summary written to: {{ANALYSIS_FOLDER}}/proposed_changes.md
   PROPOSE_SUMMARY_END
__SYSKIT_TEMPLATE_END__

# --- .syskit/prompts/propose-validate.md ---
info "Creating .syskit/prompts/propose-validate.md"
cat > ".syskit/prompts/propose-validate.md" << '__SYSKIT_TEMPLATE_END__'
# Propose Validation — Subagent Instructions

You are reviewing proposed specification changes for quality.

Read all modified files listed in `{{ANALYSIS_FOLDER}}/proposed_changes.md` from the `doc/` directories.

Check each modified document for:

1. Requirement statements use condition/response format ("When X, the system SHALL Y")
2. No implementation details in requirements (data layouts, register fields belong in interfaces)
3. Each requirement is singular (not compound)
4. Cross-references (REQ-NNN, INT-NNN, UNIT-NNN) are valid and consistent
5. Changes align with the rationale described in proposed_changes.md

If you find fixable issues, edit the doc files directly to correct them.

Return ONLY this summary:

VALIDATION_SUMMARY_START
Documents reviewed: <n>
Issues found: <n>
Issues corrected: <n>
Issues requiring human review: <n> — <brief descriptions if any>
VALIDATION_SUMMARY_END
__SYSKIT_TEMPLATE_END__

# --- .syskit/ref/cross-references.md ---
info "Creating .syskit/ref/cross-references.md"
cat > ".syskit/ref/cross-references.md" << '__SYSKIT_TEMPLATE_END__'
# Cross-Reference Reference

## Identifiers

- `REQ-001` — Requirement 001 (top-level)
- `REQ-001.03` — Requirement 001.03 (child of REQ-001)
- `INT-005` — Interface 005
- `UNIT-012` — Design unit 012

Identifiers are derived from filenames: `req_001_foo.md` → `REQ-001`, `req_001.03_bar.md` → `REQ-001.03`

## Hierarchical Requirement Numbering

Child requirements use dot-notation to show their parent relationship:

- Top-level: `req_004_motor_control.md` → `REQ-004`
- Child: `req_004.01_voltage_levels.md` → `REQ-004.01`
- Grandchild: `req_004.01.03_overvoltage_protection.md` → `REQ-004.01.03`

Top-level IDs use 3-digit padding (`NNN`). Each child level uses 2-digit padding (`.NN`).

## Bidirectional Links

The following links must be maintained bidirectionally:

- REQ "Allocated To" ↔ UNIT "Implements Requirements"
- REQ "Interfaces" ↔ INT "Referenced By"
- UNIT "Provides" ↔ INT "Parties Provider"
- UNIT "Consumes" ↔ INT "Parties Consumer"

## Cross-Reference Sync

After modifying cross-references, run the sync tool:

```bash
.syskit/scripts/trace-sync.sh          # check mode — report issues
.syskit/scripts/trace-sync.sh --fix    # fix mode — add missing back-references
```

This tool verifies bidirectional links and reports broken references (IDs with no matching file) and orphan documents.

**Important:** Do not write custom scripts for traceability updates. Use `trace-sync.sh`.
__SYSKIT_TEMPLATE_END__

# --- .syskit/ref/document-formats.md ---
info "Creating .syskit/ref/document-formats.md"
cat > ".syskit/ref/document-formats.md" << '__SYSKIT_TEMPLATE_END__'
# Document Format Reference

## Requirements (`req_NNN_<name>.md`)

Requirements state WHAT the system must do, not HOW.

See `.syskit/ref/requirement-format.md` for the required format, quality criteria, and level-of-abstraction guidance.

## Interfaces (`int_NNN_<name>.md`)

Interfaces define contracts. They may be:

- **Internal:** Defined by this project (register maps, packet formats, internal APIs)
- **External:** Defined elsewhere (PNG format, SPI protocol, USB spec)

For external interfaces, document:

- The external specification and version
- How this system uses/constrains it
- What subset of features are supported

For internal interfaces, the document IS the specification.

## Design Units (`unit_NNN_<name>.md`)

Design units describe HOW a piece of the system works.

- Reference requirements being implemented with `REQ-NNN`
- Reference interfaces being implemented/consumed with `INT-NNN`
- Document internal interfaces to other units
- Link to implementation files in `src/`
__SYSKIT_TEMPLATE_END__

# --- .syskit/ref/requirement-format.md ---
info "Creating .syskit/ref/requirement-format.md"
cat > ".syskit/ref/requirement-format.md" << '__SYSKIT_TEMPLATE_END__'
# Requirement Format Reference

## Required Format

Every requirement must use the condition/response pattern:

> **When** [condition/trigger], the system **SHALL/SHOULD/MAY** [observable behavior/response].

- **SHALL** = mandatory, **SHOULD** = recommended, **MAY** = optional
- Reference interfaces with `INT-NNN`
- Allocate to design units with `UNIT-NNN`

## Quality Criteria

Each requirement must be:

- **Necessary:** Removing it would cause a system deficiency
- **Singular:** Addresses one thing only — split compound requirements
- **Correct:** Accurately describes the needed capability
- **Unambiguous:** Has only one possible interpretation — no vague terms
- **Feasible:** Can be implemented within known constraints
- **Appropriate to Level:** Describes capabilities/behaviors, not implementation mechanisms
- **Complete:** Contains all information needed to implement and verify
- **Conforming:** Uses the project's standard template and condition/response format
- **Verifiable:** The condition defines the test setup; the behavior defines the pass criterion

## Level of Abstraction

If a requirement describes data layout, register fields, byte encoding, packet structure, memory maps, or wire protocols, that detail belongs in an interface document (`INT-NNN`), not a requirement. The requirement should reference the interface.

- Wrong: "The system SHALL have an error counter" *(no condition, not testable)*
- Wrong: "The system SHALL transmit a 16-byte header with bytes 0-3 as a big-endian sequence number" *(implementation detail, belongs in an interface)*
- Right: "When the system receives a malformed message, the system SHALL discard the message and increment the error counter"
- Right: "When the system transmits a message, the system SHALL include a unique sequence number per INT-005"
__SYSKIT_TEMPLATE_END__

# --- .syskit/ref/spec-ref.md ---
info "Creating .syskit/ref/spec-ref.md"
cat > ".syskit/ref/spec-ref.md" << '__SYSKIT_TEMPLATE_END__'
# Spec-ref: Implementation Traceability Reference

Source files that implement a design unit include a `Spec-ref` comment linking back to the unit document:

```text
// Spec-ref: unit_006_pixel_pipeline.md `a1b2c3d4e5f6g7h8` 2026-02-11
```

- Filename: the design unit document basename
- Hash: 16-char truncated SHA256 of the unit file content (same format as manifest)
- Date: when the implementation was last synced to the spec
- Comment prefix matches the source language (`//`, `//!`, `#`, `--`, etc.)

## Checking Implementation Freshness

```bash
.syskit/scripts/impl-check.sh              # full scan → .syskit/impl-status.md
.syskit/scripts/impl-check.sh UNIT-006     # single unit → stdout
```

Status meanings:

- ✓ current — implementation hash matches current spec
- ⚠ stale — spec has changed since implementation was last synced
- ✗ missing — Spec-ref points to a unit file that does not exist
- ○ untracked — unit lists source files but none have Spec-ref back-references

## Updating Spec-ref Hashes

After implementing spec changes, update the Spec-ref hashes:

```bash
.syskit/scripts/impl-stamp.sh UNIT-006
```

This reads the unit's `## Implementation` section, computes the current SHA256 of the unit file, and updates the hash and date in each source file's Spec-ref comment. It also warns about:

- Source files listed in ## Implementation that have no Spec-ref line
- Source files with Spec-ref to this unit that are not listed in ## Implementation (orphans)

**Important:** Do not manually edit Spec-ref hash values or write scripts to update them. Always use `impl-stamp.sh`.

## Creating New Implementation Files

When creating a new implementation file, add a placeholder Spec-ref line:

```text
// Spec-ref: unit_NNN_name.md `0000000000000000` 1970-01-01
```

Then run `impl-stamp.sh UNIT-NNN` to set the correct hash.
__SYSKIT_TEMPLATE_END__

# --- .claude/commands/syskit-guide.md ---
info "Creating .claude/commands/syskit-guide.md"
cat > ".claude/commands/syskit-guide.md" << '__SYSKIT_TEMPLATE_END__'
---
description: Interactive guide for getting started with syskit
arguments:
  - name: system
    description: Brief description of your system or project (e.g., "LED controller with SPI interface")
    required: false
---

# syskit Guide

You are guiding a user through getting started with syskit in this project.

If `$ARGUMENTS.system` is provided, use it to tailor examples and suggestions to their system.

## Instructions

### Step 1: Detect Scenario

List all files in `doc/requirements/`, `doc/interfaces/`, and `doc/design/`.

Ignore template files (filenames containing `_000_template`).

- If **no non-template documents** exist → follow **Path A: Fresh Project** (Step 2A)
- If **non-template documents** exist → follow **Path B: Existing Project** (Step 2B)

---

## Path A: Fresh Project

### Step 2A: Orient

Explain the project structure syskit has set up:

1. **`doc/requirements/`** — What the system must do. Each file is a requirement (REQ-NNN).
2. **`doc/interfaces/`** — Contracts between components and external systems. Each file is an interface (INT-NNN).
3. **`doc/design/`** — How each piece of the system works. Each file is a design unit (UNIT-NNN).
4. **`.syskit/`** — Tooling: scripts, manifest, working folders for analysis and tasks.

Explain the naming convention:
- `req_001_motor_control.md` → referenced as `REQ-001`
- `req_001.01_torque_limit.md` → referenced as `REQ-001.01` (child of REQ-001)
- `int_002_spi_bus.md` → referenced as `INT-002`
- `unit_003_pwm_driver.md` → referenced as `UNIT-003`

Explain that requirements support hierarchical numbering — child requirements use dot-notation (e.g., `REQ-001.03`) so the parent relationship is visible from the ID itself.

Explain that these documents cross-reference each other to create a traceability web:
- Requirements reference the interfaces they use and the design units that implement them
- Design units reference the requirements they satisfy and the interfaces they provide or consume

### Step 3A: Create a Requirement

Ask the user what their first requirement should be about. Use `$ARGUMENTS.system` for context if provided.

Once they respond, create the requirement:

1. Run `.syskit/scripts/new-req.sh <name>` with a snake_case name based on their description
2. Read the created file
3. Walk the user through filling in each section interactively — ask them questions to populate:
   - **Classification:** Help them choose Priority (Essential/Important/Nice-to-have), Stability (Stable/Evolving/Volatile), and Verification method
   - **Requirement statement:** Help them write the requirement in condition/response format: "When [condition], the system SHALL [observable behavior]."
     Before finalizing the statement, validate it against the quality criteria:
     1. **Condition/Response format** — Does it follow "When X, the system SHALL Y"? If not, help identify the trigger condition that makes this testable.
     2. **Singular** — Does it address exactly one thing? If it uses "and" or "or" to combine distinct capabilities, split it into separate requirements.
     3. **Appropriate Level** — Does it describe a capability or behavior (correct) rather than data layout, register fields, or encoding details (too low-level)? If it specifies struct fields, byte offsets, or protocol encoding, move that detail to an interface document and have the requirement reference the interface instead.
     4. **Unambiguous** — Could two engineers interpret this differently? Eliminate vague terms like "fast", "efficient", "appropriate".
     5. **Necessary** — Is this requirement essential, or is it an implementation detail that belongs in a design unit?
     If the statement fails any check, explain the issue to the user and help them revise it before proceeding.
   - **Rationale:** Ask why this requirement exists
4. Leave **Allocated To** and **Interfaces** as TBD — these will be filled in after creating those documents

Write the completed content to the file.

### Step 4A: Create an Interface

Ask the user what interface is relevant to the requirement just created. For example, if the requirement involves communication, the interface might be a protocol or data format.

Once they respond:

1. Run `.syskit/scripts/new-int.sh <name>`
2. Read the created file
3. Walk the user through:
   - **Type:** Internal, External Standard, or External Service
   - **Parties:** Leave Provider/Consumer as TBD until the design unit exists
   - **Referenced By:** Add the requirement just created (e.g., REQ-001)
   - **Specification:** Help them write at least an overview of what this interface does
   - Help the user understand that detailed data layouts, field definitions, register maps, and encoding specifications belong here in the interface document — not in requirements. If the user described low-level details during requirement creation that were redirected here, incorporate them into the interface specification.

Write the completed content to the file.

### Step 5A: Create a Design Unit

Ask the user what component or module will implement the requirement.

Once they respond:

1. Run `.syskit/scripts/new-unit.sh <name>`
2. Read the created file
3. Walk the user through:
   - **Purpose:** What this unit does
   - **Implements Requirements:** Link to the requirement from Step 3A
   - **Interfaces — Provides/Consumes:** Link to the interface from Step 4A
   - **Design Description:** Help them describe how it works at a high level

Write the completed content to the file.

### Step 6A: Wire Up Cross-References

Now go back and complete the cross-references:

1. Edit the requirement file:
   - Set **Allocated To** → the design unit just created (e.g., UNIT-001)
   - Set **Interfaces** → the interface just created (e.g., INT-001)

2. Edit the interface file:
   - Set **Provider/Consumer** in Parties → the design unit (e.g., UNIT-001)

Explain to the user how this traceability web works: every requirement traces forward to what implements it, and every design unit traces back to why it exists.

### Step 7A: Update Manifest and Explain Workflow

Run `.syskit/scripts/manifest.sh` to record the current state of all documents.

Explain:
- The manifest (`.syskit/manifest.md`) stores SHA256 hashes of every spec document
- This enables **freshness checking** — syskit detects when specs have changed between workflow steps, preventing work based on stale analysis

Then explain the four-command change workflow for future changes:

1. **`/syskit-impact`** — Describe a change; syskit analyzes which specs are affected
2. **`/syskit-propose`** — Review and approve proposed modifications to affected specs
3. **`/syskit-plan`** — Break approved spec changes into implementation tasks
4. **`/syskit-implement`** — Execute tasks one by one with verification

Tell the user: "You're set up. When you want to make a change, start with `/syskit-impact` and describe what you want to change."

---

## Path B: Existing Project

### Step 2B: Overview

Provide a brief inventory of existing documents:

1. Count and list documents by type:
   - **Requirements:** List each file's ID and title (e.g., `REQ-001: Motor Control`)
   - **Interfaces:** List each file's ID and title (e.g., `INT-001: SPI Bus`)
   - **Design Units:** List each file's ID and title (e.g., `UNIT-001: PWM Driver`)
2. Note any special documents present: `states_and_modes.md`, `quality_metrics.md`, `design_decisions.md`, `concept_of_execution.md`

### Step 3B: Explain the Structure

Explain the conventions this project uses:

1. **Naming:** `req_NNN_name.md` → `REQ-NNN` (child requirements: `req_NNN.NN_name.md` → `REQ-NNN.NN`), `int_NNN_name.md` → `INT-NNN`, `unit_NNN_name.md` → `UNIT-NNN`
2. **Cross-references:** Documents link to each other using these IDs to create traceability:
   - Requirements → Interfaces they use, Design Units that implement them
   - Design Units → Requirements they satisfy, Interfaces they provide/consume
3. **Manifest:** `.syskit/manifest.md` stores SHA256 hashes for freshness checking between workflow steps

### Step 4B: Explain the Change Workflow

Walk through how to make changes in this project:

1. **`/syskit-impact <description>`** — Start here. Describe what you want to change. Syskit analyzes which specs are affected and creates an impact report.
2. **`/syskit-propose`** — Proposes specific edits to affected specs. You review and approve before any specs are modified.
3. **`/syskit-plan`** — Creates an implementation task breakdown from approved spec changes.
4. **`/syskit-implement`** — Executes tasks one by one with verification.

Also mention helper scripts for creating new documents:
- `.syskit/scripts/new-req.sh <name>` — Create a new requirement
- `.syskit/scripts/new-int.sh <name>` — Create a new interface
- `.syskit/scripts/new-unit.sh <name>` — Create a new design unit

### Step 5B: Offer Next Steps

Ask the user what they'd like to do:

- Create a new requirement, interface, or design unit to get hands-on practice
- Run `/syskit-impact` on a change they have in mind
- Ask questions about the existing specifications
__SYSKIT_TEMPLATE_END__

# --- .claude/commands/syskit-impact.md ---
info "Creating .claude/commands/syskit-impact.md"
cat > ".claude/commands/syskit-impact.md" << '__SYSKIT_TEMPLATE_END__'
---
description: Analyze impact of a proposed change across all specifications
arguments:
  - name: change
    description: Description of the proposed change
    required: true
---

# Impact Analysis

You are analyzing the impact of a proposed change on this project's specifications.

## Proposed Change

$ARGUMENTS.change

## Instructions

### Step 0: Context Check

If this conversation already contains output from a previous syskit command (look for IMPACT_SUMMARY, PROPOSE_SUMMARY, CHUNK_SUMMARY, PLAN_SUMMARY, or IMPLEMENT_SUMMARY markers, or previous `/syskit-*` command invocations), STOP and tell the user:

"This conversation already has syskit command history in context. Start a fresh conversation to run `/syskit-impact` — all progress is saved to disk and will be picked up automatically."

If the user explicitly included `--continue` in their command, skip this check and proceed.

### Step 1: Read Manifest

Read `.syskit/manifest.md` to get the current list of all specification documents and their hashes.

Count the total number of specification documents listed (excluding any with `_000_template` in the name). You will use this count to validate the subagent's output.

### Step 2: Create Analysis Folder

Create the analysis folder: `.syskit/analysis/{{DATE}}_<change_name>/`

Also create a draft staging directory: `.syskit/analysis/_draft/`

### Step 3: Delegate Document Analysis

Use the Task tool to launch a subagent that reads and analyzes all specification documents. This keeps the full document contents out of your context window.

Launch a `general-purpose` Task agent with this prompt (substitute the actual proposed change for PROPOSED_CHANGE, and the analysis folder path for ANALYSIS_FOLDER):

> Read your full instructions from `.syskit/prompts/impact-analysis.md`.
>
> Use these values for placeholders in the prompt file:
> - `{{PROPOSED_CHANGE}}`: PROPOSED_CHANGE
> - `{{ANALYSIS_FOLDER}}`: ANALYSIS_FOLDER
>
> Follow the instructions in the prompt file. Return ONLY the compact summary described at the end.

The subagent will return a summary in `IMPACT_SUMMARY_START`/`IMPACT_SUMMARY_END` format.

### Step 4: Validate Analysis

After the subagent returns:

1. Parse the summary counts from the `IMPACT_SUMMARY_START`/`IMPACT_SUMMARY_END` block
2. Compare the "Total" count against the count you computed from the manifest in Step 1
3. If any documents are missing, list them and warn the user
4. If the subagent failed or returned incomplete results, tell the user and offer to re-run

Do NOT read the full `impact.md` into context. Use the summary to validate.

### Step 5: Generate Snapshot

Run: `.syskit/scripts/manifest-snapshot.sh .syskit/analysis/{{DATE}}_<change_name>/`

Clean up the draft staging directory:

```bash
rm -rf .syskit/analysis/_draft/
```

### Step 6: Next Step

Present the summary counts to the user and tell them:

"Impact analysis complete. Results saved to `.syskit/analysis/<folder>/impact.md`.

Next step: run `/syskit-propose` to propose specific changes to the affected documents.

Tip: Start a new conversation before running the next command to free up context."
__SYSKIT_TEMPLATE_END__

# --- .claude/commands/syskit-implement.md ---
info "Creating .claude/commands/syskit-implement.md"
cat > ".claude/commands/syskit-implement.md" << '__SYSKIT_TEMPLATE_END__'
---
description: Execute implementation tasks from the current plan
arguments:
  - name: task
    description: Task number to implement (optional, continues from current or starts at 1)
    required: false
---

# Implement Task

You are orchestrating implementation of tasks from the current implementation plan. The actual implementation work is delegated to a subagent to keep your context lean.

## Instructions

### Step 0: Context Check

If this conversation already contains output from a previous syskit command (look for IMPACT_SUMMARY, PROPOSE_SUMMARY, CHUNK_SUMMARY, PLAN_SUMMARY, or IMPLEMENT_SUMMARY markers, or previous `/syskit-*` command invocations), STOP and tell the user:

"This conversation already has syskit command history in context. Start a fresh conversation to run `/syskit-implement` — all progress is saved to disk and will be picked up automatically."

If the user explicitly included `--continue` in their command, skip this check and proceed.

### Steps 1–3: Find Task, Check Freshness, Check Dependencies

Run the combined task-discovery script (single command covers task lookup, freshness, and dependency checks):

```bash
.syskit/scripts/find-task.sh $ARGUMENTS.task
```

(Omit the argument if `$ARGUMENTS.task` was not provided.)

Parse the structured output between `FIND_TASK_START` / `FIND_TASK_END`:

- **`all_complete: true`** → Report completion and stop.
- **`freshness: stale`** → Warn the user with `freshness_detail`. Recommend re-running `/syskit-plan` if changes are significant.
- **`deps_ok: false`** → Show `deps_detail`. Prompt the user to complete dependencies first or offer to implement the dependency instead.
- **`task_file`** → Path to the task file to implement (used in Step 4).
- **`task_folder`** → Path to the task folder (used in Step 4).
- **`pending_remaining`** → Number of pending tasks (used in Step 7).

### Step 4: Delegate Implementation

Launch a `general-purpose` Task agent with this prompt (substitute TASK_FILE with the full path to the task file, TASK_FOLDER with the task folder path, and TIMESTAMP with the current date/time):

> Read your full instructions from `.syskit/prompts/implement-task.md`.
>
> Your assignment:
> - Task file: TASK_FILE
> - Task folder: TASK_FOLDER
> - Timestamp: TIMESTAMP
>
> In the prompt file, replace `{{TASK_FILE}}` with your task file path, `{{TASK_FOLDER}}` with the task folder path, and `{{TIMESTAMP}}` with the timestamp.
>
> Follow the instructions in the prompt file. Return ONLY the compact summary described at the end.

### Step 5: Validate Results

After the subagent returns:

1. Parse the `IMPLEMENT_SUMMARY_START`/`IMPLEMENT_SUMMARY_END` block
2. Check that all verification criteria passed
3. If the subagent failed or returned incomplete results, tell the user and offer to re-run

If any verification criteria failed, tell the user which ones and ask how to proceed.

### Step 6: Post-Implementation Scripts

Run these scripts to verify consistency:

```bash
.syskit/scripts/trace-sync.sh
```

If trace-sync reports issues, run `.syskit/scripts/trace-sync.sh --fix` and report what was fixed.

For each design unit referenced by the task, update Spec-ref hashes:

```bash
.syskit/scripts/impl-stamp.sh UNIT-NNN
```

Then verify implementation freshness:

```bash
.syskit/scripts/impl-check.sh
```

Report any issues from these scripts to the user.

### Step 7: Next Steps

After completing the task:

1. Check if there are more pending tasks (scan task file headers for `Status: Pending`)
2. If yes, tell the user:

"Task <n> complete.

Next: run `/syskit-implement` in a new conversation to continue with the next pending task."

3. If no, run `.syskit/scripts/manifest.sh` to update the manifest, then report: "All tasks complete. Manifest updated."

Also remind to update any design documents if implementation details changed.
__SYSKIT_TEMPLATE_END__

# --- .claude/commands/syskit-plan.md ---
info "Creating .claude/commands/syskit-plan.md"
cat > ".claude/commands/syskit-plan.md" << '__SYSKIT_TEMPLATE_END__'
---
description: Create implementation task breakdown from approved specification changes
arguments:
  - name: analysis
    description: Name of the analysis folder (optional, uses most recent if not specified)
    required: false
---

# Plan Implementation Tasks

You are creating an implementation task breakdown based on approved specification changes.

## Instructions

### Step 0: Context Check

If this conversation already contains output from a previous syskit command (look for IMPACT_SUMMARY, PROPOSE_SUMMARY, CHUNK_SUMMARY, PLAN_SUMMARY, or IMPLEMENT_SUMMARY markers, or previous `/syskit-*` command invocations), STOP and tell the user:

"This conversation already has syskit command history in context. Start a fresh conversation to run `/syskit-plan` — all progress is saved to disk and will be picked up automatically."

If the user explicitly included `--continue` in their command, skip this check and proceed.

### Step 1: Load Approved Changes

If `$ARGUMENTS.analysis` is provided:

- Find the analysis folder: `.syskit/analysis/$ARGUMENTS.analysis/`

Otherwise:

- Find the most recent folder in `.syskit/analysis/`

Read ONLY the first ~10 lines of `proposed_changes.md` to check the `Status:` line. If status is not "Approved", prompt user to run `/syskit-propose` first.

Note the analysis folder path and the change name — you will pass these to the subagent.

### Step 2: Delegate Scope Extraction

Use the Task tool to launch a subagent that reads the affected documents and design units to extract implementation scope. This keeps the full document contents out of your context window.

The subagent reads all needed files from disk — do NOT embed proposed_changes.md content in the prompt.

Launch a `general-purpose` Task agent with this prompt (substitute ANALYSIS_FOLDER and TASK_FOLDER):

> Read your full instructions from `.syskit/prompts/plan-extract.md`.
>
> Use these values for placeholders in the prompt file:
> - `{{ANALYSIS_FOLDER}}`: ANALYSIS_FOLDER
> - `{{TASK_FOLDER}}`: TASK_FOLDER (use `.syskit/tasks/{{DATE}}_<change_name>/`)
>
> Follow the instructions in the prompt file. Return ONLY the compact summary described at the end.

The subagent will return a summary in `PLAN_SUMMARY_START`/`PLAN_SUMMARY_END` format.

### Step 3: Validate Plan

After the subagent returns:

1. Parse the summary to verify the task folder was created and tasks were written
2. Verify the task count is reasonable for the scope of changes
3. If the subagent failed or returned incomplete results, tell the user and offer to re-run

Do NOT read the full plan.md or task files into context. Use the summary to validate.

### Step 4: Generate Snapshot

Run: `.syskit/scripts/manifest-snapshot.sh <task-folder-path>`

### Step 5: Present Plan

Present the task sequence from the subagent's summary and tell the user:

"Implementation plan created with <n> tasks in `<task-folder>`.

**Task sequence:**
<paste the task sequence from the summary>

Next step: run `/syskit-implement` to begin working through the tasks.

Tip: Start a new conversation before running the next command to free up context."
__SYSKIT_TEMPLATE_END__

# --- .claude/commands/syskit-propose.md ---
info "Creating .claude/commands/syskit-propose.md"
cat > ".claude/commands/syskit-propose.md" << '__SYSKIT_TEMPLATE_END__'
---
description: Propose specific modifications to specifications based on impact analysis
arguments:
  - name: analysis
    description: Name of the analysis folder (optional, uses most recent if not specified)
    required: false
---

# Propose Specification Changes

You are proposing specific modifications to specifications based on a completed impact analysis.

## Instructions

### Step 0: Context Check

If this conversation already contains output from a previous syskit command (look for IMPACT_SUMMARY, PROPOSE_SUMMARY, CHUNK_SUMMARY, PLAN_SUMMARY, or IMPLEMENT_SUMMARY markers, or previous `/syskit-*` command invocations), STOP and tell the user:

"This conversation already has syskit command history in context. Start a fresh conversation to run `/syskit-propose` — all progress is saved to disk and will be picked up automatically."

If the user explicitly included `--continue` in their command, skip this check and proceed.

### Step 1: Check Git Status

Run `git status -- doc/` to check for uncommitted changes in the doc directory.

If there are uncommitted changes in `doc/`, **stop and tell the user:**

"There are uncommitted changes in `doc/`. Please commit or stash them before running `/syskit-propose`, so that proposed changes can be reviewed with `git diff` and reverted cleanly if needed."

### Step 2: Load the Impact Analysis

If `$ARGUMENTS.analysis` is provided:

- Find the analysis folder: `.syskit/analysis/$ARGUMENTS.analysis/`

Otherwise:

- Find the most recent folder in `.syskit/analysis/`

Read ONLY the `## Summary` section from `impact.md` (the last ~15 lines) to get document counts and the list of affected filenames. Do NOT load the full impact.md into context.

Also note the proposed change description from the first few lines of impact.md.

Note the analysis folder path — you will pass it to subagents.

### Step 3: Check Freshness

Run the freshness check script:

```bash
.syskit/scripts/manifest-check.sh .syskit/analysis/<folder>/snapshot.md
```

- If any affected documents have changed (exit code 1), warn the user
- Recommend re-running impact analysis if changes are significant
- Proceed with caution if user confirms

### Step 4: Count Affected Documents

From the summary counts, determine the number of documents with Action Required of "modify" or "review" (across Direct, Interface, and Dependent categories).

### Step 5: Delegate Change Drafting

Choose the delegation strategy based on the count of affected documents:

- **8 or fewer affected documents:** Use a single subagent (Step 5a)
- **More than 8 affected documents:** Use chunked subagents (Step 5b)

#### Step 5a: Single Subagent

Launch a `general-purpose` Task agent with this prompt (substitute ANALYSIS_FOLDER and PROPOSED_CHANGE):

> Read your full instructions from `.syskit/prompts/propose-single.md`.
>
> Use these values for placeholders in the prompt file:
> - `{{PROPOSED_CHANGE}}`: PROPOSED_CHANGE
> - `{{ANALYSIS_FOLDER}}`: ANALYSIS_FOLDER
>
> Follow the instructions in the prompt file. Return ONLY the compact summary described at the end.

The subagent will return a summary in `PROPOSE_SUMMARY_START`/`PROPOSE_SUMMARY_END` format.

#### Step 5b: Chunked Subagents

Split the affected documents into groups of at most 8, keeping related documents together (e.g., a requirement and the interface it references in the same group).

For each chunk, launch a `general-purpose` Task agent with this prompt (substitute ANALYSIS_FOLDER, PROPOSED_CHANGE, CHUNK_NUMBER, and ASSIGNED_FILES):

> Read your full instructions from `.syskit/prompts/propose-chunk.md`.
>
> Use these values for placeholders in the prompt file:
> - `{{PROPOSED_CHANGE}}`: PROPOSED_CHANGE
> - `{{ANALYSIS_FOLDER}}`: ANALYSIS_FOLDER
> - `{{CHUNK_NUMBER}}`: CHUNK_NUMBER
> - `{{ASSIGNED_FILES}}`: ASSIGNED_FILES
>
> Follow the instructions in the prompt file. Return ONLY the compact summary described at the end.

Launch all chunk agents in parallel where possible.

After ALL chunk agents complete, assemble the final summary:

1. Create the header for `proposed_changes.md` with the change name, timestamp, status, and a change summary table built from the chunk summaries
2. Use bash to assemble: `.syskit/scripts/assemble-chunks.sh .syskit/analysis/<folder>/proposed_changes.md .syskit/analysis/<folder>/ "chunk_*.md"`
3. Prepend the header to the assembled file

### Step 6: Validate Proposed Changes

After the subagent(s) return:

1. Parse the summary to verify all affected documents were edited
2. Note any quality warnings reported
3. If the subagent failed or returned incomplete results, tell the user and offer to re-run

If the change set affects 5 or more documents, launch a validation Task agent:

> Read your full instructions from `.syskit/prompts/propose-validate.md`.
>
> Use this value for placeholders in the prompt file:
> - `{{ANALYSIS_FOLDER}}`: ANALYSIS_FOLDER
>
> Follow the instructions in the prompt file. Return ONLY the compact summary described at the end.

The subagent will return a summary in `VALIDATION_SUMMARY_START`/`VALIDATION_SUMMARY_END` format.

### Step 7: Present Changes for Review

Tell the user:

"Proposed changes have been applied directly to the doc files. Review the changes using `git diff doc/` or the VSCode source control panel.

**Summary:**
<paste the change summary table from the subagent's returned summary>

**Quality warnings:** <list any, or 'None'>

Reply with:
- **'approve'** to keep all changes and proceed to planning
- **'approve \<filename\>'** to keep changes to a specific file and revert others
- **'revise \<filename\>'** to discuss modifications to a specific file
- **'reject'** to revert all changes (`git checkout -- doc/`)"

### Step 8: Handle Approval

- **approve:** Update `Status: Pending Approval` to `Status: Approved` in `.syskit/analysis/<folder>/proposed_changes.md`. Proceed to Step 9.
- **approve \<filename\>:** Revert all other files with `git checkout -- doc/<other files>`, keep the specified file(s). Update `Status: Pending Approval` to `Status: Approved` in `.syskit/analysis/<folder>/proposed_changes.md`. Proceed to Step 9.
- **revise \<filename\>:** Discuss the specific file with the user, make adjustments, then re-present.
- **reject:** Run `git checkout -- doc/` to revert all changes. Tell the user the proposal has been discarded.

### Step 9: Next Step

After applying approved changes, tell the user:

"Proposed changes applied. Summary saved to `.syskit/analysis/<folder>/proposed_changes.md`.

Next step: run `/syskit-plan` to create an implementation task breakdown.

Tip: Start a new conversation before running the next command to free up context."
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/CLAUDE_SYSKIT.md ---
info "Creating .syskit/templates/CLAUDE_SYSKIT.md"
cat > ".syskit/templates/CLAUDE_SYSKIT.md" << '__SYSKIT_TEMPLATE_END__'
## syskit

This project uses **syskit** for specification-driven development. Specifications in `doc/` define what the system must do, how components interact, and how the design is structured. Implementation follows from specs. When creating new specifications, define interfaces and requirements before design — understand the contracts and constraints before deciding how to build.

### Working with code

- Source files may contain `Spec-ref:` comments linking to design units — **preserve these; never edit the hash manually**.
- Before modifying code, check `doc/design/` for a relevant design unit (`unit_NNN_*.md`) that describes the component's intended behavior.
- After code changes, run `.syskit/scripts/impl-check.sh` to verify spec-to-implementation freshness.
- After spec changes, run `.syskit/scripts/impl-stamp.sh UNIT-NNN` to update Spec-ref hashes in source files.

### Making changes

For non-trivial changes affecting system behavior, use the syskit workflow:

1. `/syskit-impact <change>` — Analyze what specifications are affected
2. `/syskit-propose` — Propose specification updates
3. `/syskit-plan` — Break into implementation tasks
4. `/syskit-implement` — Execute with traceability

New to syskit? Run `/syskit-guide` for an interactive walkthrough.

### Reference

- Specifications: `doc/requirements/`, `doc/interfaces/`, `doc/design/`
- Working documents: `.syskit/analysis/`, `.syskit/tasks/`
- Scripts: `.syskit/scripts/`
- Full instructions: `.syskit/AGENTS.md` (read on demand, not auto-loaded)
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/requirements/req_000_template.md ---
info "Creating .syskit/templates/doc/requirements/req_000_template.md"
cat > ".syskit/templates/doc/requirements/req_000_template.md" << '__SYSKIT_TEMPLATE_END__'
# REQ-000: Template

This is a template file. Create new requirements using:

```bash
.syskit/scripts/new-req.sh <requirement_name>
```

Or copy this template and modify.

---

## Classification

- **Priority:** Essential | Important | Nice-to-have
- **Stability:** Stable | Evolving | Volatile
- **Verification:** Test | Analysis | Inspection | Demonstration

## Requirement

When [condition/trigger], the system SHALL [observable behavior/response].

Format: **When** [condition], the system **SHALL/SHOULD/MAY** [behavior].

- Each requirement must have a testable trigger condition and observable outcome
- Describe capabilities/behaviors, not data layout or encoding
- For struct fields, byte formats, protocols → create an interface (INT-NNN) and reference it

## Rationale

<Why this requirement exists. What problem does it solve? What drives this need?>

## Parent Requirements

- REQ-NNN (<parent requirement name>)
- Or "None" if this is a top-level requirement
- Child requirements use hierarchical IDs: REQ-NNN.NN (e.g., REQ-004.01 is a child of REQ-004)

## Allocated To

- UNIT-NNN (<unit name>)

## Interfaces

- INT-NNN (<interface name>)

## Verification Method

<How this requirement will be verified>

- **Test:** Verified by executing a test procedure
- **Analysis:** Verified by technical evaluation
- **Inspection:** Verified by examination
- **Demonstration:** Verified by operation

## Notes

<Additional context, open questions, or references>
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/requirements/quality_metrics.md ---
info "Creating .syskit/templates/doc/requirements/quality_metrics.md"
cat > ".syskit/templates/doc/requirements/quality_metrics.md" << '__SYSKIT_TEMPLATE_END__'
# Quality Metrics

This document defines the quality attributes and metrics for the system.

## Performance

### <Metric Name>

- **Requirement:** <quantified requirement>
- **Measurement Method:** <how it will be measured>
- **Target:** <target value>
- **Minimum Acceptable:** <threshold>
- **References:** REQ-NNN

## Reliability

### <Metric Name>

- **Requirement:** <quantified requirement>
- **Measurement Method:** <how it will be measured>
- **Target:** <target value>
- **References:** REQ-NNN

## Resource Utilization

### Memory Usage

- **Requirement:** <constraint>
- **Budget Allocation:**
  - UNIT-NNN: <allocation>
  - UNIT-NNN: <allocation>
- **References:** REQ-NNN

### FPGA Resources

- **LUT Budget:** <total available>
- **Register Budget:** <total available>
- **BRAM Budget:** <total available>
- **Allocation:**
  - UNIT-NNN: <allocation>
- **References:** REQ-NNN

## Timing

### <Timing Constraint>

- **Requirement:** <constraint>
- **Analysis Method:** <how it will be verified>
- **References:** REQ-NNN

## Maintainability

### Code Complexity

- **Requirement:** <constraint, e.g., max cyclomatic complexity>
- **Measurement:** <tool or method>

### Documentation Coverage

- **Requirement:** <constraint>
- **Measurement:** <how verified>

## Test Coverage

### Unit Test Coverage

- **Target:** <percentage>
- **Measurement:** <tool>

### Requirement Coverage

- **Target:** 100% of SHALL requirements
- **Measurement:** Traceability analysis
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/requirements/states_and_modes.md ---
info "Creating .syskit/templates/doc/requirements/states_and_modes.md"
cat > ".syskit/templates/doc/requirements/states_and_modes.md" << '__SYSKIT_TEMPLATE_END__'
# States and Modes

This document defines the operational states and modes of the system.

## Definitions

- **State:** A condition of the system characterized by specific behaviors and capabilities
- **Mode:** A variant of operation that affects how the system behaves within a state

## System States

### State: <state name>

- **Description:** <what this state means>
- **Entry Conditions:** <how the system enters this state>
- **Exit Conditions:** <how the system leaves this state>
- **Capabilities:** <what the system can do in this state>
- **Restrictions:** <what the system cannot do in this state>

## Operational Modes

### Mode: <mode name>

- **Description:** <what this mode means>
- **Applicable States:** <which states this mode applies to>
- **Configuration:** <how this mode is selected>
- **Behavior Differences:** <how behavior differs from other modes>

## State Transition Diagram

```
                    ┌─────────────┐
         ┌─────────▶│   State A   │─────────┐
         │          └─────────────┘         │
         │                │                 │
    [condition]      [condition]       [condition]
         │                │                 │
         │                ▼                 │
    ┌────┴────┐     ┌─────────────┐         │
    │ State C │◀────│   State B   │◀────────┘
    └─────────┘     └─────────────┘
```

## State Transition Table

| Current State | Event / Condition | Next State | Actions |
|---------------|-------------------|------------|---------|
| <state> | <trigger> | <state> | <actions> |

## Mode Compatibility Matrix

| Mode | State A | State B | State C |
|------|---------|---------|---------|
| Mode 1 | ✓ | ✓ | ✗ |
| Mode 2 | ✓ | ✗ | ✓ |
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/interfaces/int_000_template.md ---
info "Creating .syskit/templates/doc/interfaces/int_000_template.md"
cat > ".syskit/templates/doc/interfaces/int_000_template.md" << '__SYSKIT_TEMPLATE_END__'
# INT-000: Template

This is a template file. Create new interfaces using:

```bash
.syskit/scripts/new-int.sh <interface_name>
```

Or copy this template and modify.

---

## Type

Choose one:
- **Internal:** Defined by this project
- **External Standard:** Defined by an external specification (e.g., PNG, SPI, USB)
- **External Service:** Defined by an external service (e.g., REST API)

## External Specification

<!-- Include this section only for external interfaces -->

- **Standard:** <name and version, e.g., "SPI Mode 0", "PNG 1.2">
- **Reference:** <URL or document reference>

## Parties

- **Provider:** UNIT-NNN (<unit name>) | External
- **Consumer:** UNIT-NNN (<unit name>)

Multiple consumers are common. List all units that use this interface.

## Referenced By

- REQ-NNN (<requirement name>)

List all requirements that reference this interface.

## Specification

<!-- For internal interfaces: This section IS the specification -->
<!-- For external interfaces: Document your usage subset and constraints -->

### Overview

<Brief description of what this interface is for>

### Details

<Detailed specification>

For hardware interfaces, consider:
- Signal definitions
- Timing requirements
- Electrical characteristics

For data formats, consider:
- Field definitions
- Encoding
- Constraints and valid ranges

For APIs, consider:
- Endpoints / functions
- Parameters
- Return values
- Error conditions

## Constraints

<Any constraints or limitations>

## Notes

<Additional context, rationale for choices, compatibility considerations>
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/design/unit_000_template.md ---
info "Creating .syskit/templates/doc/design/unit_000_template.md"
cat > ".syskit/templates/doc/design/unit_000_template.md" << '__SYSKIT_TEMPLATE_END__'
# UNIT-000: Template

This is a template file. Create new design units using:

```bash
.syskit/scripts/new-unit.sh <unit_name>
```

Or copy this template and modify.

---

## Purpose

<What this unit does and why it exists>

A design unit is a cohesive piece of the system that can be implemented and tested somewhat independently. It might be:
- A Verilog module
- A C source file or library
- A class or module in higher-level languages
- A logical grouping of closely related code

## Implements Requirements

- REQ-NNN (<requirement name>)

List all requirements this unit helps satisfy.

## Interfaces

### Provides

- INT-NNN (<interface name>)

Interfaces this unit implements (is the provider of).

### Consumes

- INT-NNN (<interface name>)

Interfaces this unit uses (is a consumer of).

### Internal Interfaces

- Connects to UNIT-NNN via <description>

Internal connections not formally specified as interfaces.

## Design Description

<How this unit works>

### Inputs

<Input signals, parameters, or data>

### Outputs

<Output signals, parameters, or data>

### Internal State

<Any internal state maintained by this unit>

### Algorithm / Behavior

<Description of the unit's behavior, state machines, data flow>

## Implementation

- `<filepath>`: <description>

List all source files that implement this unit.

## Verification

- `<test filepath>`: <what it tests>

List all test files for this unit.

## Design Notes

<Additional design considerations>

Consider documenting:
- Alternatives considered and why they were rejected
- Performance characteristics
- Resource usage (for FPGA: LUTs, registers, BRAM)
- Known limitations
- Future improvement ideas
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/design/concept_of_execution.md ---
info "Creating .syskit/templates/doc/design/concept_of_execution.md"
cat > ".syskit/templates/doc/design/concept_of_execution.md" << '__SYSKIT_TEMPLATE_END__'
# Concept of Execution

This document describes the runtime behavior of the system: how it starts up, how data flows through it, and how it responds to events.

## System Overview

<High-level description of what the system does at runtime>

## Operational Modes

Reference: `doc/requirements/states_and_modes.md`

<Describe how the system behaves in each operational mode>

## Startup Sequence

<What happens when the system powers on or initializes>

1. <Step 1>
2. <Step 2>
3. ...

## Data Flow

<How data moves through the system>

Consider using a diagram:

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│ Input   │────▶│ Process │────▶│ Output  │
└─────────┘     └─────────┘     └─────────┘
```

## Event Handling

<How the system responds to events>

### Event: <event name>

- **Source:** <where the event comes from>
- **Handler:** UNIT-NNN
- **Response:** <what happens>

## Timing and Synchronization

<Any timing requirements or synchronization mechanisms>

## Error Handling

<How errors are detected and handled>

## Resource Management

<How resources (memory, buffers, connections) are managed>
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/design/design_decisions.md ---
info "Creating .syskit/templates/doc/design/design_decisions.md"
cat > ".syskit/templates/doc/design/design_decisions.md" << '__SYSKIT_TEMPLATE_END__'
# Design Decisions

This document records significant design decisions using a lightweight Architecture Decision Record (ADR) format.

## Template

When adding a new decision, copy this template:

```markdown
## DD-NNN: <Title>

**Date:** YYYY-MM-DD  
**Status:** Proposed | Accepted | Superseded by DD-XXX

### Context

<What is the issue or question that needs a decision?>

### Decision

<What is the decision that was made?>

### Rationale

<Why was this decision made? What alternatives were considered?>

### Consequences

<What are the implications of this decision?>
```

---

## Decisions

<!-- Add decisions below, newest first -->
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/requirements/README.md ---
info "Creating .syskit/templates/doc/requirements/README.md"
cat > ".syskit/templates/doc/requirements/README.md" << '__SYSKIT_TEMPLATE_END__'
# Requirements

*Software Requirements Specification (SRS) for <system name>*

This directory contains the system requirements specification — the authoritative record of **what** the system must do.

## System Overview

<Brief description of the system: what it is, what it does, and its operational context.>

## Document Description

<Brief overview of what this document covers and how it is organized.>

## Purpose

Each requirement document defines a single, testable system behavior using the condition/response pattern:

> **When** [condition], the system **SHALL/SHOULD/MAY** [behavior].

Requirements are traceable: each is allocated to design units (`UNIT-NNN`) and references interfaces (`INT-NNN`). Together they form a complete, verifiable description of system capability.

## Conventions

- **Naming:** `req_NNN_<name>.md` — 3-digit zero-padded number, lowercase, underscores
- **Child requirements:** `req_NNN.NN_<name>.md` — dot-notation encodes parent (e.g., `req_004.01_voltage_levels.md`)
- **Create new:** `.syskit/scripts/new-req.sh <name>` or `.syskit/scripts/new-req.sh --parent REQ-NNN <name>`
- **Cross-references:** Use `REQ-NNN` or `REQ-NNN.NN` identifiers (derived from filename)
- **Hierarchy:** Parent relationship is visible in the ID; `Parent Requirements` field provides explicit back-reference

## Framework Documents

- **quality_metrics.md** — Quality attributes, targets, and measurement methods
- **states_and_modes.md** — System operational states, modes, and transitions

## Table of Contents

<!-- TOC-START -->
*Run `.syskit/scripts/toc-update.sh` to generate.*
<!-- TOC-END -->
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/interfaces/README.md ---
info "Creating .syskit/templates/doc/interfaces/README.md"
cat > ".syskit/templates/doc/interfaces/README.md" << '__SYSKIT_TEMPLATE_END__'
# Interfaces

*Interface Design Description (IDD) for <system name>*

This directory contains the interface specifications — the authoritative record of **contracts** between components and with external systems.

## System Overview

<Brief description of the system: what it is, what it does, and its operational context.>

## Document Description

<Brief overview of what this document covers and how it is organized.>

## Purpose

Each interface document defines a precise contract: data formats, protocols, APIs, or signal definitions that components agree on. Interfaces are the bridge between requirements (what) and design (how), ensuring components can be developed and tested independently.

Interface types:

- **Internal** — Defined by this project (register maps, packet formats, internal APIs)
- **External Standard** — Defined by an external spec (PNG, SPI, USB)
- **External Service** — Defined by an external service (REST API, cloud endpoint)

## Conventions

- **Naming:** `int_NNN_<name>.md` — 3-digit zero-padded number, lowercase, underscores
- **Create new:** `.syskit/scripts/new-int.sh <name>`
- **Cross-references:** Use `INT-NNN` identifiers (derived from filename)
- **Parties:** Each interface has a Provider and one or more Consumers

## Table of Contents

<!-- TOC-START -->
*Run `.syskit/scripts/toc-update.sh` to generate.*
<!-- TOC-END -->
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/design/README.md ---
info "Creating .syskit/templates/doc/design/README.md"
cat > ".syskit/templates/doc/design/README.md" << '__SYSKIT_TEMPLATE_END__'
# Design

*Software Design Description (SDD) for <system name>*

This directory contains the design specification — the authoritative record of **how** the system accomplishes its requirements.

## System Overview

<Brief description of the system: what it is, what it does, and its operational context.>

## Document Description

<Brief overview of what this document covers and how it is organized.>

## Purpose

Each design unit document describes a cohesive piece of the system: its purpose, the requirements it satisfies, the interfaces it provides and consumes, and its internal behavior. Design units map directly to implementation — each links to source files and test files, enabling full traceability from requirement through design to code.

A design unit might be a hardware module, a source file, a library, or a logical grouping of related code.

## Conventions

- **Naming:** `unit_NNN_<name>.md` — 3-digit zero-padded number, lowercase, underscores
- **Create new:** `.syskit/scripts/new-unit.sh <name>`
- **Cross-references:** Use `UNIT-NNN` identifiers (derived from filename)
- **Traceability:** Source files link back via `Spec-ref` comments; use `impl-stamp.sh` to keep hashes current

## Framework Documents

- **concept_of_execution.md** — System runtime behavior, startup, data flow, and event handling
- **design_decisions.md** — Architecture Decision Records (ADR format)

## Table of Contents

<!-- TOC-START -->
*Run `.syskit/scripts/toc-update.sh` to generate.*
<!-- TOC-END -->
__SYSKIT_TEMPLATE_END__

# Copy-templates: always overwrite
info "Updating copy-templates in doc/..."
cp .syskit/templates/doc/requirements/req_000_template.md doc/requirements/req_000_template.md
cp .syskit/templates/doc/interfaces/int_000_template.md doc/interfaces/int_000_template.md
cp .syskit/templates/doc/design/unit_000_template.md doc/design/unit_000_template.md

# Framework docs: only create if missing
for tmpl in \
    "doc/requirements/quality_metrics.md" \
    "doc/requirements/states_and_modes.md" \
    "doc/design/concept_of_execution.md" \
    "doc/design/design_decisions.md" \
    "doc/requirements/README.md" \
    "doc/interfaces/README.md" \
    "doc/design/README.md"
do
    if [ ! -f "$tmpl" ]; then
        info "Creating $tmpl"
        cp ".syskit/templates/$tmpl" "$tmpl"
    else
        info "Skipping $tmpl (already exists)"
    fi
done

# Update table of contents in README files
info "Updating doc README table of contents..."
.syskit/scripts/toc-update.sh

# Generate initial manifest
info "Generating manifest..."
.syskit/scripts/manifest.sh

# Create/update CLAUDE.md to reference syskit
SYSKIT_MD=".syskit/templates/CLAUDE_SYSKIT.md"

if [ -f "CLAUDE.md" ]; then
    if grep -q "<!-- syskit-start -->" "CLAUDE.md"; then
        info "Updating syskit section in CLAUDE.md"
        awk -v sf="$SYSKIT_MD" '
            /<!-- syskit-start -->/ {
                skip=1
                print "<!-- syskit-start -->"
                while ((getline line < sf) > 0) print line
                close(sf)
                print "<!-- syskit-end -->"
                next
            }
            /<!-- syskit-end -->/ { skip=0; next }
            !skip
        ' CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
    elif ! grep -q "## syskit" "CLAUDE.md"; then
        info "Adding syskit section to CLAUDE.md"
        {
            echo ""
            echo "<!-- syskit-start -->"
            cat "$SYSKIT_MD"
            echo "<!-- syskit-end -->"
        } >> CLAUDE.md
    else
        warn "CLAUDE.md has a syskit section without update markers."
        warn "To enable automatic updates, wrap it with <!-- syskit-start --> and <!-- syskit-end -->"
    fi
else
    info "Creating CLAUDE.md"
    {
        echo "# Project Instructions"
        echo ""
        echo "<!-- syskit-start -->"
        cat "$SYSKIT_MD"
        echo "<!-- syskit-end -->"
    } > CLAUDE.md
fi

info ""
info "syskit installed successfully!"
info ""
info "Next steps:"
info "  Run /syskit-guide for an interactive walkthrough"
info ""
info "See .syskit/AGENTS.md for full documentation."
