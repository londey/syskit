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
mkdir -p doc/verification
mkdir -p .syskit/scripts
mkdir -p .syskit/prompts
mkdir -p .syskit/ref
mkdir -p .syskit/analysis
mkdir -p .syskit/tasks
mkdir -p .syskit/templates/doc/requirements
mkdir -p .syskit/templates/doc/interfaces
mkdir -p .syskit/templates/doc/design
mkdir -p .syskit/templates/doc/verification
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
- `doc/verification/` — How requirements are verified
- `ARCHITECTURE.md` — Auto-generated architecture overview with block diagram (project root)

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
- **Verification** (`ver_NNN_<name>.md`) — HOW requirements are verified. Links to requirements and design units.

## Key Principle

**Reference, don't reproduce.** Don't restate information that is defined elsewhere — reference the source.

- **Internal documents:** Reference by ID (`REQ-NNN`, `INT-NNN`, `UNIT-NNN`, `VER-NNN`). Each fact should have exactly one authoritative location in `doc/`.
- **External standards:** Reference by name, version/year, and section or figure number (e.g., "ISO 26262-6:2018 §8.4.4", "RFC 9293 §3.1", "PNG 1.2 §4.1.3"). Don't paraphrase normative text — cite the section that defines it.
- **Scope:** Applies to specification documents and code (comments, docstrings). Working files in `.syskit/` are exempt.

For detailed format and style guidance, see `.syskit/ref/document-formats.md`.

## Workflows

**Important:** Always invoke syskit scripts using workspace-relative paths (e.g., `.syskit/scripts/manifest.sh`). Never expand these to absolute paths.

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
5. User reviews changes via `git diff doc/` and approves, refines, or rejects

### Refining Changes (Iterative)

After proposing, the user may want to iterate on the proposed changes before approving:

1. Run `/syskit-refine --feedback "<what needs to change>"` to fix issues in the proposal
2. Review updated changes via `git diff doc/`
3. Repeat with additional `/syskit-refine` runs as needed (each in a new conversation)
4. Run `/syskit-approve` when satisfied (or approve inline during propose/refine)

Use refine to fix issues in proposed changes — wrong decisions, missing coverage, incorrect interfaces, etc.

### Approving Changes

Approval can happen inline (during `/syskit-propose` or `/syskit-refine`) or in a separate session:

1. Run `/syskit-approve` to review and approve pending changes from any previous session
2. The approve command reads the analysis folder, shows the current diff, and updates `proposed_changes.md` status
3. This enables overnight reviews — propose in one session, review at your leisure, approve in another

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
6. After doc changes, run `.syskit/scripts/arch-update.sh` to refresh ARCHITECTURE.md
7. After doc changes, run `.syskit/scripts/manifest.sh` to update the manifest
8. Run `.syskit/scripts/template-check.sh` to verify documents conform to current templates

### Context Budget Management

The workflow commands use subagents to keep document content out of the main context window. Follow these rules to prevent context exhaustion:

1. **Subagents write to disk, return only summaries** — A subagent's final message becomes a tool result in the main context. Keep return messages under 1KB. Write detailed output to files in `.syskit/analysis/` or `.syskit/tasks/`.

2. **Subagents read large files from disk** — Never paste file content larger than 2KB into a subagent prompt. Instead, give the subagent the file path and let it read the file itself.

3. **Chunk large change sets** — When more than 8 documents are affected, use multiple subagents each handling a subset. Assemble results with `.syskit/scripts/assemble-chunks.sh`.

4. **Validate via summaries, not content** — Verify subagent work by checking counts and file lists in the returned summary. Do not read large output files into the main context for review.

5. **Edit doc files directly** — Subagents edit `doc/` files in place. The user reviews via `git diff`. This eliminates the largest context consumer (full proposed content for every affected file).

6. **One command per conversation** — Each syskit command persists all state to disk. Start a fresh conversation for each command to avoid context accumulation.

## Template Conformance

Documents may drift from their templates when templates are updated between installer runs. The template-check script verifies that all required sections are present:

```bash
.syskit/scripts/template-check.sh                  # check all documents
.syskit/scripts/template-check.sh --type req        # check requirements only
.syskit/scripts/template-check.sh doc/design/unit_001_core.md  # check one file
```

Exit code 0 means all documents conform; exit code 1 means missing sections were found. When editing an existing document, run the check on that file first — if the template has gained new sections since the document was written, add them before making other changes.

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
.syskit/scripts/new-int.sh --parent INT-005 <name>
.syskit/scripts/new-unit.sh <name>
.syskit/scripts/new-unit.sh --parent UNIT-002 <name>
.syskit/scripts/new-ver.sh <name>
.syskit/scripts/new-ver.sh --parent VER-001 <name>
```

## Cross-References

Use `REQ-NNN`, `INT-NNN`, `UNIT-NNN`, `VER-NNN` identifiers (or `REQ-NNN.NN`, `INT-NNN.NN`, `UNIT-NNN.NN`, `VER-NNN.NN` for children) when referencing between documents.

For detailed cross-reference rules and the sync tool, see `.syskit/ref/cross-references.md`.

For Spec-ref implementation traceability, see `.syskit/ref/spec-ref.md`.

## Architecture Overview

After adding or modifying design units, refresh the architecture overview:

```bash
.syskit/scripts/arch-update.sh
```

This updates the Mermaid block diagram and unit summary table in `ARCHITECTURE.md` between guard tags.
__SYSKIT_TEMPLATE_END__

# --- .syskit/scripts/arch-update.sh ---
info "Creating .syskit/scripts/arch-update.sh"
cat > ".syskit/scripts/arch-update.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Update the auto-generated section of ARCHITECTURE.md
# Parses doc/design/unit_*.md files to generate a Mermaid block diagram
# and a unit summary table between syskit-arch guard tags.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ARCH_FILE="$PROJECT_ROOT/ARCHITECTURE.md"
UNIT_DIR="$PROJECT_ROOT/doc/design"

cd "$PROJECT_ROOT"

if [ ! -f "$ARCH_FILE" ]; then
    echo "ARCHITECTURE.md not found." >&2
    exit 1
fi

if ! grep -q '<!-- syskit-arch-start -->' "$ARCH_FILE"; then
    echo "ARCHITECTURE.md has no <!-- syskit-arch-start --> marker. Cannot update." >&2
    exit 1
fi

# Require bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: bash 4+ required (found ${BASH_VERSION})" >&2
    exit 1
fi

# ─── Section Parser (same pattern as trace-sync.sh) ──────────────

section_lines() { # <file> <heading> <level>
    awk -v section="$2" -v level="$3" '
        BEGIN { found = 0 }
        $0 == section { found = 1; next }
        found && /^#/ { match($0, /^#+/); if (RLENGTH <= level) exit }
        found { print }
    ' "$1"
}

section_ids() { # <file> <heading> <level> <id_pattern>
    section_lines "$1" "$2" "$3" | grep -oE "$4" | sort -u || true
}

# Extract first non-empty, non-placeholder line from ## Purpose
purpose_text() { # <file>
    section_lines "$1" "## Purpose" 2 \
        | grep -v '^\s*$' \
        | grep -v '^<' \
        | head -1 \
        | sed 's/^ *//'
}

# ─── Data Collection ─────────────────────────────────────────────

INT_PAT='INT-[0-9]{3}(\.[0-9]{2})?'

declare -a UNIT_IDS=()
declare -A UNIT_TITLE
declare -A UNIT_PURPOSE
declare -A UNIT_PROVIDES
declare -A UNIT_CONSUMES
declare -A UNIT_IS_CHILD
declare -A UNIT_PARENT

for f in $(printf '%s\n' "$UNIT_DIR"/unit_*.md 2>/dev/null | LC_COLLATE=C sort); do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [[ "$base" == *_000_template* ]] && continue

    # Extract UNIT ID and title from H1
    h1=$(head -1 "$f")
    id=$(echo "$h1" | grep -oE 'UNIT-[0-9]{3}(\.[0-9]{2})?' || true)
    [ -z "$id" ] && continue

    title=$(echo "$h1" | sed "s/^# *${id}: *//")

    # Detect child vs parent
    if [[ "$id" =~ ^UNIT-([0-9]{3})\.[0-9]{2}$ ]]; then
        UNIT_IS_CHILD["$id"]="true"
        UNIT_PARENT["$id"]="UNIT-${BASH_REMATCH[1]}"
    else
        UNIT_IS_CHILD["$id"]="false"
    fi

    UNIT_IDS+=("$id")
    UNIT_TITLE["$id"]="$title"
    UNIT_PURPOSE["$id"]=$(purpose_text "$f")
    UNIT_PROVIDES["$id"]=$(section_ids "$f" "### Provides" 3 "$INT_PAT")
    UNIT_CONSUMES["$id"]=$(section_ids "$f" "### Consumes" 3 "$INT_PAT")
done

# ─── Build Interface Maps ────────────────────────────────────────

declare -A INT_PROVIDER    # INT-NNN -> UNIT-NNN
declare -A INT_CONSUMERS   # INT-NNN -> space-separated UNIT-NNN list

for id in "${UNIT_IDS[@]}"; do
    for int_id in ${UNIT_PROVIDES[$id]:-}; do
        INT_PROVIDER["$int_id"]="$id"
    done
    for int_id in ${UNIT_CONSUMES[$id]:-}; do
        INT_CONSUMERS["$int_id"]="${INT_CONSUMERS[$int_id]:-}${INT_CONSUMERS[$int_id]:+ }$id"
    done
done

# ─── Generate Content ────────────────────────────────────────────

# Helper: convert UNIT-NNN or UNIT-NNN.NN to a valid Mermaid node name
node_name() {
    echo "$1" | tr '.' '_' | tr '-' '_'
}

CONTENT_TMP=$(mktemp)
trap 'rm -f "$CONTENT_TMP"' EXIT

{
    # ── Mermaid Diagram ──
    echo "### Block Diagram"
    echo ""
    echo '```mermaid'
    echo "flowchart LR"

    if [ ${#UNIT_IDS[@]} -eq 0 ]; then
        echo "    %% No design units found"
    else
        # Emit nodes: parents with children as subgraphs, others as plain nodes
        for id in "${UNIT_IDS[@]}"; do
            [ "${UNIT_IS_CHILD[$id]}" = "true" ] && continue

            node=$(node_name "$id")

            # Check if this unit has children
            has_children=false
            for cid in "${UNIT_IDS[@]}"; do
                if [ "${UNIT_PARENT[$cid]:-}" = "$id" ]; then
                    has_children=true
                    break
                fi
            done

            if $has_children; then
                echo "    subgraph ${node}[\"${id}: ${UNIT_TITLE[$id]}\"]"
                for cid in "${UNIT_IDS[@]}"; do
                    [ "${UNIT_PARENT[$cid]:-}" = "$id" ] || continue
                    c_node=$(node_name "$cid")
                    echo "        ${c_node}[\"${cid}: ${UNIT_TITLE[$cid]}\"]"
                done
                echo "    end"
            else
                echo "    ${node}[\"${id}: ${UNIT_TITLE[$id]}\"]"
            fi
        done

        # Emit interface edges
        for int_id in $(echo "${!INT_PROVIDER[@]}" | tr ' ' '\n' | LC_COLLATE=C sort); do
            provider="${INT_PROVIDER[$int_id]}"
            for consumer in ${INT_CONSUMERS[$int_id]:-}; do
                p_node=$(node_name "$provider")
                c_node=$(node_name "$consumer")
                echo "    ${p_node} -->|${int_id}| ${c_node}"
            done
        done
    fi

    echo '```'
    echo ""

    # ── Unit Summary Table ──
    echo "### Software Units"
    echo ""

    if [ ${#UNIT_IDS[@]} -eq 0 ]; then
        echo "*No design units found.*"
    else
        echo "| Unit | Title | Purpose |"
        echo "|------|-------|---------|"
        for id in "${UNIT_IDS[@]}"; do
            purpose="${UNIT_PURPOSE[$id]:-—}"
            [ -z "$purpose" ] && purpose="—"
            echo "| ${id} | ${UNIT_TITLE[$id]} | ${purpose} |"
        done
    fi
} > "$CONTENT_TMP"

# ─── Replace Guard Section ───────────────────────────────────────

TMP="${ARCH_FILE}.tmp"

awk -v sf="$CONTENT_TMP" '
    /<!-- syskit-arch-start -->/ {
        skip=1
        print "<!-- syskit-arch-start -->"
        while ((getline line < sf) > 0) print line
        close(sf)
        print "<!-- syskit-arch-end -->"
        next
    }
    /<!-- syskit-arch-end -->/ { skip=0; next }
    !skip
' "$ARCH_FILE" > "$TMP" && mv "$TMP" "$ARCH_FILE"

echo "ARCHITECTURE.md updated."
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/arch-update.sh"

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
hash_directory "doc/verification" "Verification"

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

PARENT=""
if [ "${1:-}" = "--parent" ]; then
    PARENT="$2"
    shift 2
fi

NAME="${1:-}"

if [ -z "$NAME" ]; then
    echo "Usage: new-int.sh [--parent INT-NNN] <interface_name>"
    echo "Example: new-int.sh register_map"
    echo "Example: new-int.sh --parent INT-003 uart_registers"
    exit 1
fi

# Sanitize name: lowercase, replace spaces/hyphens with underscores
NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

mkdir -p "$INT_DIR"

if [ -n "$PARENT" ]; then
    # ─── Child interface: INT-NNN.NN under parent ──────────────

    # Extract numeric prefix from parent ID (e.g., INT-005 → 005)
    PARENT_NUM=$(echo "$PARENT" | sed 's/^INT-//')

    if ! [[ "$PARENT_NUM" =~ ^[0-9]{3}$ ]]; then
        echo "Error: invalid parent ID '$PARENT' (expected INT-NNN)" >&2
        exit 1
    fi

    # Warn if parent file doesn't exist
    PARENT_FILE=$(find "$INT_DIR" -maxdepth 1 -name "int_${PARENT_NUM}_*.md" -print -quit 2>/dev/null)
    if [ -z "$PARENT_FILE" ]; then
        echo "Warning: parent $PARENT has no matching file in $INT_DIR" >&2
    fi

    # Find next available child number under this parent
    NEXT_CHILD=1
    for f in "$INT_DIR"/int_${PARENT_NUM}.[0-9][0-9]_*.md; do
        if [ -f "$f" ]; then
            CHILD_NUM=$(basename "$f" | sed "s/int_${PARENT_NUM}\.\([0-9][0-9]\)_.*/\1/" | sed 's/^0*//')
            CHILD_NUM=${CHILD_NUM:-0}
            [[ "$CHILD_NUM" =~ ^[1-9][0-9]*$ ]] || continue
            if [ "$CHILD_NUM" -ge "$NEXT_CHILD" ]; then
                NEXT_CHILD=$((10#$CHILD_NUM + 1))
            fi
        fi
    done

    CHILD_PADDED=$(printf "%02d" $NEXT_CHILD)
    NUM_PART="${PARENT_NUM}.${CHILD_PADDED}"
    FILENAME="int_${NUM_PART}_${NAME}.md"
    FILEPATH="$INT_DIR/$FILENAME"
    ID="INT-${NUM_PART}"
else
    # ─── Top-level interface: INT-NNN ──────────────────────────

    NEXT_NUM=1
    for f in "$INT_DIR"/int_[0-9][0-9][0-9]_*.md; do
        if [ -f "$f" ]; then
            NUM=$(basename "$f" | sed 's/int_\([0-9]*\)_.*/\1/' | sed 's/^0*//')
            NUM=${NUM:-0}  # Default to 0 if empty
            [[ "$NUM" =~ ^[1-9][0-9]*$ ]] || continue
            if [ "$NUM" -ge "$NEXT_NUM" ]; then
                NEXT_NUM=$((10#$NUM + 1))
            fi
        fi
    done

    NUM_PADDED=$(printf "%03d" $NEXT_NUM)
    FILENAME="int_${NUM_PADDED}_${NAME}.md"
    FILEPATH="$INT_DIR/$FILENAME"
    ID="INT-${NUM_PADDED}"
fi

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
    echo "Usage: new-req.sh [--parent REQ-NNN] <requirement_name>"
    echo "Example: new-req.sh spi_interface"
    echo "Example: new-req.sh --parent REQ-001 spi_voltage_levels"
    exit 1
fi

# Sanitize name: lowercase, replace spaces/hyphens with underscores
NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

mkdir -p "$REQ_DIR"

if [ -n "$PARENT" ]; then
    # ─── Child requirement: REQ-NNN.NN under parent ──────────────

    # Extract numeric prefix from parent ID (e.g., REQ-004 → 004, REQ-004.01 → 004.01)
    PARENT_NUM=$(echo "$PARENT" | sed 's/^REQ-//')

    if ! [[ "$PARENT_NUM" =~ ^[0-9]{3}$ ]]; then
        echo "Error: invalid parent ID '$PARENT' (expected REQ-NNN)" >&2
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
            [[ "$CHILD_NUM" =~ ^[1-9][0-9]*$ ]] || continue
            if [ "$CHILD_NUM" -ge "$NEXT_CHILD" ]; then
                NEXT_CHILD=$((10#$CHILD_NUM + 1))
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
            [[ "$NUM" =~ ^[1-9][0-9]*$ ]] || continue
            if [ "$NUM" -ge "$NEXT_NUM" ]; then
                NEXT_NUM=$((10#$NUM + 1))
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

## Verified By

- VER-NNN (<verification name>)

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

PARENT=""
if [ "${1:-}" = "--parent" ]; then
    PARENT="$2"
    shift 2
fi

NAME="${1:-}"

if [ -z "$NAME" ]; then
    echo "Usage: new-unit.sh [--parent UNIT-NNN] <unit_name>"
    echo "Example: new-unit.sh spi_slave"
    echo "Example: new-unit.sh --parent UNIT-002 pid_controller"
    exit 1
fi

# Sanitize name: lowercase, replace spaces/hyphens with underscores
NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

mkdir -p "$UNIT_DIR"

if [ -n "$PARENT" ]; then
    # ─── Child unit: UNIT-NNN.NN under parent ──────────────

    # Extract numeric prefix from parent ID (e.g., UNIT-002 → 002)
    PARENT_NUM=$(echo "$PARENT" | sed 's/^UNIT-//')

    if ! [[ "$PARENT_NUM" =~ ^[0-9]{3}$ ]]; then
        echo "Error: invalid parent ID '$PARENT' (expected UNIT-NNN)" >&2
        exit 1
    fi

    # Warn if parent file doesn't exist
    PARENT_FILE=$(find "$UNIT_DIR" -maxdepth 1 -name "unit_${PARENT_NUM}_*.md" -print -quit 2>/dev/null)
    if [ -z "$PARENT_FILE" ]; then
        echo "Warning: parent $PARENT has no matching file in $UNIT_DIR" >&2
    fi

    # Find next available child number under this parent
    NEXT_CHILD=1
    for f in "$UNIT_DIR"/unit_${PARENT_NUM}.[0-9][0-9]_*.md; do
        if [ -f "$f" ]; then
            CHILD_NUM=$(basename "$f" | sed "s/unit_${PARENT_NUM}\.\([0-9][0-9]\)_.*/\1/" | sed 's/^0*//')
            CHILD_NUM=${CHILD_NUM:-0}
            [[ "$CHILD_NUM" =~ ^[1-9][0-9]*$ ]] || continue
            if [ "$CHILD_NUM" -ge "$NEXT_CHILD" ]; then
                NEXT_CHILD=$((10#$CHILD_NUM + 1))
            fi
        fi
    done

    CHILD_PADDED=$(printf "%02d" $NEXT_CHILD)
    NUM_PART="${PARENT_NUM}.${CHILD_PADDED}"
    FILENAME="unit_${NUM_PART}_${NAME}.md"
    FILEPATH="$UNIT_DIR/$FILENAME"
    ID="UNIT-${NUM_PART}"
else
    # ─── Top-level unit: UNIT-NNN ──────────────────────────

    NEXT_NUM=1
    for f in "$UNIT_DIR"/unit_[0-9][0-9][0-9]_*.md; do
        if [ -f "$f" ]; then
            NUM=$(basename "$f" | sed 's/unit_\([0-9]*\)_.*/\1/' | sed 's/^0*//')
            NUM=${NUM:-0}  # Default to 0 if empty
            [[ "$NUM" =~ ^[1-9][0-9]*$ ]] || continue
            if [ "$NUM" -ge "$NEXT_NUM" ]; then
                NEXT_NUM=$((10#$NUM + 1))
            fi
        fi
    done

    NUM_PADDED=$(printf "%03d" $NEXT_NUM)
    FILENAME="unit_${NUM_PADDED}_${NAME}.md"
    FILEPATH="$UNIT_DIR/$FILENAME"
    ID="UNIT-${NUM_PADDED}"
fi

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

# --- .syskit/scripts/new-ver.sh ---
info "Creating .syskit/scripts/new-ver.sh"
cat > ".syskit/scripts/new-ver.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Create a new verification document
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VER_DIR="$PROJECT_ROOT/doc/verification"

PARENT=""
if [ "${1:-}" = "--parent" ]; then
    PARENT="$2"
    shift 2
fi

NAME="${1:-}"

if [ -z "$NAME" ]; then
    echo "Usage: new-ver.sh [--parent VER-NNN] <verification_name>"
    echo "Example: new-ver.sh framebuffer_approval"
    echo "Example: new-ver.sh --parent VER-002 edge_cases"
    exit 1
fi

# Sanitize name: lowercase, replace spaces/hyphens with underscores
NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

mkdir -p "$VER_DIR"

if [ -n "$PARENT" ]; then
    # ─── Child verification: VER-NNN.NN under parent ──────────────

    # Extract numeric prefix from parent ID (e.g., VER-002 → 002)
    PARENT_NUM=$(echo "$PARENT" | sed 's/^VER-//')

    if ! [[ "$PARENT_NUM" =~ ^[0-9]{3}$ ]]; then
        echo "Error: invalid parent ID '$PARENT' (expected VER-NNN)" >&2
        exit 1
    fi

    # Warn if parent file doesn't exist
    PARENT_FILE=$(find "$VER_DIR" -maxdepth 1 -name "ver_${PARENT_NUM}_*.md" -print -quit 2>/dev/null)
    if [ -z "$PARENT_FILE" ]; then
        echo "Warning: parent $PARENT has no matching file in $VER_DIR" >&2
    fi

    # Find next available child number under this parent
    NEXT_CHILD=1
    for f in "$VER_DIR"/ver_${PARENT_NUM}.[0-9][0-9]_*.md; do
        if [ -f "$f" ]; then
            CHILD_NUM=$(basename "$f" | sed "s/ver_${PARENT_NUM}\.\([0-9][0-9]\)_.*/\1/" | sed 's/^0*//')
            CHILD_NUM=${CHILD_NUM:-0}
            [[ "$CHILD_NUM" =~ ^[1-9][0-9]*$ ]] || continue
            if [ "$CHILD_NUM" -ge "$NEXT_CHILD" ]; then
                NEXT_CHILD=$((10#$CHILD_NUM + 1))
            fi
        fi
    done

    CHILD_PADDED=$(printf "%02d" $NEXT_CHILD)
    NUM_PART="${PARENT_NUM}.${CHILD_PADDED}"
    FILENAME="ver_${NUM_PART}_${NAME}.md"
    FILEPATH="$VER_DIR/$FILENAME"
    ID="VER-${NUM_PART}"
else
    # ─── Top-level verification: VER-NNN ──────────────────────────

    NEXT_NUM=1
    for f in "$VER_DIR"/ver_[0-9][0-9][0-9]_*.md; do
        if [ -f "$f" ]; then
            NUM=$(basename "$f" | sed 's/ver_\([0-9]*\)_.*/\1/' | sed 's/^0*//')
            NUM=${NUM:-0}  # Default to 0 if empty
            [[ "$NUM" =~ ^[1-9][0-9]*$ ]] || continue
            if [ "$NUM" -ge "$NEXT_NUM" ]; then
                NEXT_NUM=$((10#$NUM + 1))
            fi
        fi
    done

    NUM_PADDED=$(printf "%03d" $NEXT_NUM)
    FILENAME="ver_${NUM_PADDED}_${NAME}.md"
    FILEPATH="$VER_DIR/$FILENAME"
    ID="VER-${NUM_PADDED}"
fi

if [ -f "$FILEPATH" ]; then
    echo "Error: $FILEPATH already exists"
    exit 1
fi

cat > "$FILEPATH" << EOF
# $ID: $(echo "$NAME" | tr '_' ' ' | sed 's/\b\(.\)/\u\1/g')

## Verification Method

Choose one:
- **Test:** Verified by executing a test procedure
- **Analysis:** Verified by technical evaluation
- **Inspection:** Verified by examination
- **Demonstration:** Verified by operation

## Verifies Requirements

- REQ-NNN (<requirement name>)

## Verified Design Units

- UNIT-NNN (<unit name>)

## Preconditions

<What must be true before this verification can be executed>

## Procedure

<Step-by-step verification procedure>

1. <Step 1>
2. <Step 2>
3. ...

## Expected Results

- **Pass Criteria:** <observable outcome that means the requirement is satisfied>
- **Fail Criteria:** <observable outcome that means the requirement is NOT satisfied>

## Test Implementation

- \`<test filepath>\`: <what it tests>

## Notes

<Additional context, edge cases, known limitations>
EOF

echo "Created: $FILEPATH"
echo "ID: $ID"
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/new-ver.sh"

# --- .syskit/scripts/template-check.sh ---
info "Creating .syskit/scripts/template-check.sh"
cat > ".syskit/scripts/template-check.sh" << '__SYSKIT_TEMPLATE_END__'
#!/bin/bash
# Check document conformance against current templates
# Usage: template-check.sh [--type req|int|unit|framework] [file]
#   No arguments: full scan, generates .syskit/template-status.md
#   --type TYPE: filter to one document type
#   Single file: check just that file, stdout only
# Exit codes: 0 = all conformant, 1 = non-conformant documents found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$PROJECT_ROOT/.syskit/templates/doc"
REPORT="$PROJECT_ROOT/.syskit/template-status.md"

cd "$PROJECT_ROOT"

# Require bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: bash 4+ required (found ${BASH_VERSION})" >&2
    exit 1
fi

# ─── Argument parsing ─────────────────────────────────────────────

TYPE_FILTER=""
FILE_FILTER=""

while [ $# -gt 0 ]; do
    case "$1" in
        --type)
            TYPE_FILTER="$2"
            shift 2
            ;;
        *)
            FILE_FILTER="$1"
            shift
            ;;
    esac
done

if [ -n "$TYPE_FILTER" ]; then
    case "$TYPE_FILTER" in
        req|int|unit|ver|framework) ;;
        *)
            echo "Error: --type must be req, int, unit, ver, or framework" >&2
            exit 1
            ;;
    esac
fi

# ─── Template mapping ─────────────────────────────────────────────

# Returns the template path for a given document file, or empty if no template applies
template_for() {
    local file="$1"
    local base
    base=$(basename "$file")

    # Skip templates themselves and READMEs
    [[ "$base" == *_000_template* ]] && return
    [[ "$base" == "README.md" ]] && return

    # Numbered documents
    if [[ "$base" =~ ^req_[0-9] ]]; then
        echo "$TEMPLATE_DIR/requirements/req_000_template.md"
    elif [[ "$base" =~ ^int_[0-9] ]]; then
        echo "$TEMPLATE_DIR/interfaces/int_000_template.md"
    elif [[ "$base" =~ ^unit_[0-9] ]]; then
        echo "$TEMPLATE_DIR/design/unit_000_template.md"
    elif [[ "$base" =~ ^ver_[0-9] ]]; then
        echo "$TEMPLATE_DIR/verification/ver_000_template.md"
    # Framework docs — matched by exact name
    elif [ -f "$TEMPLATE_DIR/requirements/$base" ]; then
        echo "$TEMPLATE_DIR/requirements/$base"
    elif [ -f "$TEMPLATE_DIR/interfaces/$base" ]; then
        echo "$TEMPLATE_DIR/interfaces/$base"
    elif [ -f "$TEMPLATE_DIR/design/$base" ]; then
        echo "$TEMPLATE_DIR/design/$base"
    elif [ -f "$TEMPLATE_DIR/verification/$base" ]; then
        echo "$TEMPLATE_DIR/verification/$base"
    fi
}

# Returns the type category for a document file
doc_type() {
    local base
    base=$(basename "$1")
    if [[ "$base" =~ ^req_ ]]; then echo "req"
    elif [[ "$base" =~ ^int_ ]]; then echo "int"
    elif [[ "$base" =~ ^unit_ ]]; then echo "unit"
    elif [[ "$base" =~ ^ver_ ]]; then echo "ver"
    else echo "framework"
    fi
}

# ─── Section extraction from template ─────────────────────────────

# Extract required heading lines from a template file
# For numbered templates: skip preamble above first ---
# Returns heading lines like "## Classification", "### Provides"
extract_headings() {
    local tmpl="$1"
    local base
    base=$(basename "$tmpl")
    local skip_preamble=false

    # Numbered templates have a preamble above ---
    if [[ "$base" == *_000_template* ]]; then
        skip_preamble=true
    fi

    awk -v skip="$skip_preamble" '
        BEGIN { past_sep = (skip == "false") ? 1 : 0 }
        !past_sep && /^---[[:space:]]*$/ { past_sep = 1; next }
        past_sep && /^##+ / { print }
    ' "$tmpl"
}

# ─── Collect documents to check ───────────────────────────────────

declare -a DOC_FILES=()

collect_docs() {
    local f base tmpl dtype

    if [ -n "$FILE_FILTER" ]; then
        # Single file mode
        if [ ! -f "$FILE_FILTER" ]; then
            echo "Error: file not found: $FILE_FILTER" >&2
            exit 1
        fi
        DOC_FILES+=("$FILE_FILTER")
        return
    fi

    # Scan doc directories
    for dir in doc/requirements doc/interfaces doc/design doc/verification; do
        [ -d "$dir" ] || continue
        for f in "$dir"/*.md; do
            [ -f "$f" ] || continue
            base=$(basename "$f")
            [[ "$base" == "README.md" ]] && continue
            [[ "$base" == *_000_template* ]] && continue

            # Apply type filter
            if [ -n "$TYPE_FILTER" ]; then
                dtype=$(doc_type "$f")
                [ "$dtype" != "$TYPE_FILTER" ] && continue
            fi

            # Only include if a template exists for this file
            tmpl=$(template_for "$f")
            [ -z "$tmpl" ] && continue
            [ -f "$tmpl" ] || continue

            DOC_FILES+=("$f")
        done
    done

    # Also check ARCHITECTURE.md at project root if it has a template
    if [ -z "$TYPE_FILTER" ] || [ "$TYPE_FILTER" = "framework" ]; then
        if [ -f "ARCHITECTURE.md" ] && [ -f "$TEMPLATE_DIR/design/ARCHITECTURE.md" ]; then
            DOC_FILES+=("ARCHITECTURE.md")
        fi
    fi
}

# ─── Check a single document against its template ─────────────────

# Populates MISSING_HEADINGS array for the given file
declare -a MISSING_HEADINGS=()

check_doc() {
    local doc="$1"
    local tmpl
    tmpl=$(template_for "$doc")
    MISSING_HEADINGS=()

    if [ -z "$tmpl" ] || [ ! -f "$tmpl" ]; then
        return
    fi

    local heading
    while IFS= read -r heading; do
        [ -z "$heading" ] && continue
        # Check if this heading exists in the document (exact line match)
        if ! grep -qFx "$heading" "$doc"; then
            MISSING_HEADINGS+=("$heading")
        fi
    done < <(extract_headings "$tmpl")
}

# ─── Main scan ─────────────────────────────────────────────────────

collect_docs

CONFORMANT_COUNT=0
NONCONFORMANT_COUNT=0

# "relpath|missing1;missing2;..." for each non-conformant doc
declare -a RESULT_LINES=()
declare -a CONFORMANT_FILES=()

for doc in $(printf '%s\n' "${DOC_FILES[@]}" | LC_COLLATE=C sort); do
    check_doc "$doc"

    if [ ${#MISSING_HEADINGS[@]} -eq 0 ]; then
        CONFORMANT_COUNT=$((CONFORMANT_COUNT + 1))
        CONFORMANT_FILES+=("$doc")
    else
        NONCONFORMANT_COUNT=$((NONCONFORMANT_COUNT + 1))
        missing_str=$(printf '%s;' "${MISSING_HEADINGS[@]}")
        missing_str="${missing_str%;}"  # trim trailing ;
        RESULT_LINES+=("${doc}|${missing_str}")
    fi
done

# ─── Report generation ─────────────────────────────────────────────

generate_report() {
    local out="/dev/stdout"
    if [ -z "$FILE_FILTER" ]; then
        out="$REPORT"
    fi

    {
        echo "# Template Conformance Status"
        echo ""
        echo "Generated: $(date -Iseconds 2>/dev/null || date)"
        echo ""
        echo "## Summary"
        echo ""
        echo "- Conformant: $CONFORMANT_COUNT"
        echo "- Non-conformant: $NONCONFORMANT_COUNT"
        echo ""

        if [ ${#RESULT_LINES[@]} -gt 0 ]; then
            echo "## Non-Conformant Documents"
            echo ""

            local entry doc_path missing_str tmpl tmpl_base
            for entry in "${RESULT_LINES[@]}"; do
                doc_path="${entry%%|*}"
                missing_str="${entry##*|}"
                tmpl=$(template_for "$doc_path")
                tmpl_base=$(basename "$tmpl")

                echo "### $doc_path"
                echo ""
                echo "Template: \`$tmpl_base\`"
                echo ""

                IFS=';' read -ra headings <<< "$missing_str"
                local h
                for h in "${headings[@]}"; do
                    echo "- Missing: \`$h\`"
                done
                echo ""
            done
        fi
    } > "$out"

    if [ -z "$FILE_FILTER" ]; then
        echo "Report written: $REPORT"
    fi
}

# ─── Stdout summary ────────────────────────────────────────────────

print_summary() {
    local doc
    for doc in "${CONFORMANT_FILES[@]}"; do
        echo "✓ conformant     — $doc"
    done

    local entry doc_path missing_str
    for entry in "${RESULT_LINES[@]}"; do
        doc_path="${entry%%|*}"
        missing_str="${entry##*|}"
        echo "⚠ non-conformant — $doc_path"

        IFS=';' read -ra headings <<< "$missing_str"
        local h
        for h in "${headings[@]}"; do
            echo "    missing: $h"
        done
    done
}

# ─── Output ────────────────────────────────────────────────────────

if [ ${#DOC_FILES[@]} -eq 0 ]; then
    echo "No documents found to check."
    exit 0
fi

if [ -z "$FILE_FILTER" ]; then
    generate_report
    echo ""
fi

print_summary

echo ""
TOTAL=$((CONFORMANT_COUNT + NONCONFORMANT_COUNT))

if [ "$NONCONFORMANT_COUNT" -eq 0 ]; then
    echo "All $TOTAL documents conform to current templates."
else
    echo "Summary: $CONFORMANT_COUNT conformant, $NONCONFORMANT_COUNT non-conformant out of $TOTAL documents"
fi

exit $((NONCONFORMANT_COUNT > 0 ? 1 : 0))
__SYSKIT_TEMPLATE_END__
chmod +x ".syskit/scripts/template-check.sh"

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
        *verification) echo "test_strategy.md" ;;
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
            req_[0-9][0-9][0-9]*.md | unit_[0-9][0-9][0-9]*.md | int_[0-9][0-9][0-9]*.md | ver_[0-9][0-9][0-9]*.md)
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
update_toc "doc/verification"

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
VER_DIR="$PROJECT_ROOT/doc/verification"

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

# Regex patterns for hierarchical IDs: XXX-NNN or XXX-NNN.NN
REQ_PAT='REQ-[0-9]{3}(\.[0-9]{2})?'
INT_PAT='INT-[0-9]{3}(\.[0-9]{2})?'
UNIT_PAT='UNIT-[0-9]{3}(\.[0-9]{2})?'
VER_PAT='VER-[0-9]{3}(\.[0-9]{2})?'

build_id_map() {
    local tag dir prefix entry base num id name
    # Scan all document types (supports hierarchical numbering: XXX-NNN or XXX-NNN.NN)
    for entry in "req:$REQ_DIR:REQ" "int:$INT_DIR:INT" "unit:$UNIT_DIR:UNIT" "ver:$VER_DIR:VER"; do
        IFS=':' read -r tag dir prefix <<< "$entry"
        [ -d "$dir" ] || continue
        for f in "$dir"/${tag}_*.md; do
            [ -f "$f" ] || continue
            base=$(basename "$f")
            [[ "$base" == *_000_template* ]] && continue
            # Match tag_NNN_name.md or tag_NNN.NN_name.md
            if [[ "$base" =~ ^${tag}_([0-9]{3}(\.[0-9]{2})?)_.+\.md$ ]]; then
                num="${BASH_REMATCH[1]}"
                id="${prefix}-${num}"
                ID_TO_FILE["$id"]="$f"
                ALL_IDS["$id"]=1
                name=$(head -1 "$f" | sed "s/^# *${prefix}-${num}: *//")
                ID_TO_NAME["$id"]="$name"
            fi
        done
    done
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
                for x in $(section_ids "$file" "## Allocated To" 2 "$UNIT_PAT"); do
                    add_ref req_alloc "$id" "$x"
                done
                for x in $(section_ids "$file" "## Interfaces" 2 "$INT_PAT"); do
                    add_ref req_iface "$id" "$x"
                done
                for x in $(section_ids "$file" "## Verified By" 2 "$VER_PAT"); do
                    add_ref req_verby "$id" "$x"
                done
                ;;
            UNIT-*)
                for x in $(section_ids "$file" "## Implements Requirements" 2 "$REQ_PAT"); do
                    add_ref unit_impl "$id" "$x"
                done
                for x in $(section_ids "$file" "### Provides" 3 "$INT_PAT"); do
                    add_ref unit_prov "$id" "$x"
                done
                for x in $(section_ids "$file" "### Consumes" 3 "$INT_PAT"); do
                    add_ref unit_cons "$id" "$x"
                done
                ;;
            VER-*)
                for x in $(section_ids "$file" "## Verifies Requirements" 2 "$REQ_PAT"); do
                    add_ref ver_req "$id" "$x"
                done
                for x in $(section_ids "$file" "## Verified Design Units" 2 "$UNIT_PAT"); do
                    add_ref ver_unit "$id" "$x"
                done
                ;;
            INT-*)
                parties=$(section_lines "$file" "## Parties" 2)
                for x in $(echo "$parties" | grep -i 'Provider' | grep -oE "$UNIT_PAT" || true); do
                    add_ref int_prov "$id" "$x"
                done
                for x in $(echo "$parties" | grep -i 'Consumer' | grep -oE "$UNIT_PAT" || true); do
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

    # VER.VerifiesRequirements <-> REQ.VerifiedBy
    check_pair ver_req req_verby \
        "Verifies Requirements" "Verified By" \
        "## Verified By" 2 list
    check_pair req_verby ver_req \
        "Verified By" "Verifies Requirements" \
        "## Verifies Requirements" 2 list

    # VER.VerifiedDesignUnits <-> UNIT.Verification
    check_pair ver_unit unit_ver \
        "Verified Design Units" "Verification" \
        "## Verification" 2 list
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

REQ_N=0 INT_N=0 UNIT_N=0 VER_N=0
for id in "${!ALL_IDS[@]}"; do
    case "$id" in
        REQ-*)  REQ_N=$((REQ_N + 1)) ;;
        INT-*)  INT_N=$((INT_N + 1)) ;;
        UNIT-*) UNIT_N=$((UNIT_N + 1)) ;;
        VER-*)  VER_N=$((VER_N + 1)) ;;
    esac
done

echo "# Traceability Sync$($FIX_MODE && echo ' (--fix)')"
echo ""
echo "Scanned: ${REQ_N} requirements, ${INT_N} interfaces, ${UNIT_N} design units, ${VER_N} verifications"
echo ""

if [ $((REQ_N + INT_N + UNIT_N + VER_N)) -eq 0 ]; then
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

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## Proposed Change

{{PROPOSED_CHANGE}}

## Instructions

1. Read ALL markdown files in these directories:
   - `doc/requirements/`
   - `doc/interfaces/`
   - `doc/design/`
   - `doc/verification/`

   Also read `ARCHITECTURE.md` from the project root (it contains manually-written sections and an auto-generated block diagram).

   Skip any files with `_000_template` in the name.

2. For each document, extract:
   - The document ID: for numbered specs, extract from the H1 heading (e.g., "REQ-001", "INT-003", "UNIT-007", "VER-002"). For framework documents (README.md, quality_metrics.md, states_and_modes.md, concept_of_execution.md, design_decisions.md, test_strategy.md) and ARCHITECTURE.md, use the filename as the identifier.
   - The document title (from the H1 heading)
   - All cross-references to other documents (REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN mentions)
   - A brief summary of what the document specifies (1-2 sentences)

3. Analyze each document against the proposed change. Categorize as:
   - **DIRECT**: The document itself describes something being changed
   - **INTERFACE**: The document defines or uses an interface affected by the change
   - **DEPENDENT**: The document depends on something being changed (via REQ/INT/UNIT references to a DIRECT or INTERFACE document)
   - **UNAFFECTED**: The document is not impacted

   When tracing dependencies:
   - If a requirement is DIRECT, check which design units have it in "Implements Requirements" (those are DEPENDENT)
   - If a requirement is DIRECT, check which interfaces it lists under "Interfaces" (those are INTERFACE)
   - If a requirement is DIRECT, check which verifications have it in "Verifies Requirements" (those are DEPENDENT)
   - If an interface is DIRECT or INTERFACE, check which units list it under "Provides" or "Consumes" (those are DEPENDENT)
   - If a design unit is DIRECT, check which requirements it implements (review for DEPENDENT impact)
   - If a design unit is DIRECT, check which verifications have it in "Verified Design Units" (those are DEPENDENT)

4. Write your complete analysis to `{{ANALYSIS_FOLDER}}/impact.md` in this format:

   ```markdown
   # Impact Analysis: <brief change summary>

   Created: <timestamp>
   Status: Pending Review

   ## Proposed Change

   <detailed description of the change>

   ## Direct Impacts

   ### <filename>
   - **ID:** <REQ/INT/UNIT/VER-NNN or filename for framework docs>
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
   - **ID:** <REQ/INT/UNIT/VER-NNN or filename for framework docs>
   - **Title:** <document title>
   - **Dependency:** <what it depends on that is changing, with specific ID>
   - **Impact:** <what specifically is affected>
   - **Action Required:** <modify/review/no change>

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
   Do not list individual unaffected documents — the summary counts are sufficient.

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

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

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
- Specification references (REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN)

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
4. If the task references VER-NNN documents and implementation changes affect verified behavior, update the verification document's Procedure and Expected Results sections to match
5. Ensure Spec-ref traceability for every design unit you implement:
   a. For each UNIT-NNN referenced by this task, read the unit document's `## Implementation` section to find the list of source files.
   b. For every file listed there — whether you created it or it already existed — verify it contains a Spec-ref comment for that unit. If it does not, add a placeholder:
      ```
      // Spec-ref: unit_NNN_name.md `0000000000000000` 1970-01-01
      ```
      Use the comment prefix appropriate for the file's language (`//` for C/Verilog/SystemVerilog, `#` for Python/Bash/Makefile, `--` for VHDL/SQL/Lua, etc.). Place it near the top of the file, after any file-level header comment or license block.
   c. If you created or modified a file that implements a unit but that file is NOT listed in the unit's `## Implementation` section, add it there in the format: `` - `path/to/file`: <brief description> ``
   d. If you used a different filename than what the `## Implementation` section lists, update the `## Implementation` entry to match the actual filename.
   e. Do not edit Spec-ref hash values manually — `impl-stamp.sh` will set them after you finish.

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

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## Instructions

1. Read the change summary from: `{{ANALYSIS_FOLDER}}/proposed_changes.md`

2. Run `git diff doc/ ARCHITECTURE.md` to see the exact specification changes that were applied.

3. Read all design unit documents (`doc/design/unit_*.md`) to understand implementation structure. Focus especially on:
   - The `## Implementation` section (lists source files)
   - The `## Implements Requirements` section (links to REQ-NNN)
   - The `## Provides` and `## Consumes` sections (links to INT-NNN)

4. Read verification documents (`doc/verification/ver_*.md`) that cover affected requirements or design units. Focus especially on:
   - The `## Verifies Requirements` section (links to REQ-NNN)
   - The `## Verified Design Units` section (links to UNIT-NNN)
   - The `## Test Implementation` section (lists test source files)

5. If the changes affected framework documents (quality_metrics.md, states_and_modes.md, concept_of_execution.md, design_decisions.md, test_strategy.md, README.md files) or `ARCHITECTURE.md`, read those files to understand what changed and whether implementation tasks are needed.

6. For each specification change, identify:
   - Which source files need modification (from design unit Implementation sections)
   - Which test files need modification or creation (from design unit and verification Test Implementation sections)
   - Which verification documents need updating if requirements or design unit behavior changed
   - Dependencies between changes (what must be done first)
   - How to verify the change was implemented correctly

7. Create the task folder: `{{TASK_FOLDER}}`

8. Write `plan.md` to the task folder:

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

9. Write individual task files `task_NNN_<name>.md` to the task folder:

   ```markdown
   # Task NNN: <task name>

   Status: Pending
   Dependencies: <list or "None">
   Specification References: <REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN>

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

10. After writing all files, return ONLY this compact summary (nothing else):

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

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## Proposed Change

{{PROPOSED_CHANGE}}

## Your Assigned Documents

{{ASSIGNED_FILES}}

## Instructions

1. Read the impact analysis from: `{{ANALYSIS_FOLDER}}/impact.md`

2. Read ONLY the documents assigned to you (listed above) from the `doc/` directories, or from the project root for `ARCHITECTURE.md`.

3. For each assigned document, **edit the file directly** with the proposed changes:
   - Make the specific modifications needed to address the proposed change
   - Ensure all cross-references (REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN) remain consistent
   - For verification documents, ensure "Verifies Requirements" and "Verified Design Units" sections reflect the current requirements and design units. Update the Procedure and Expected Results sections if the verified behavior changed.
   - For requirement documents, ensure every requirement uses the condition/response pattern: "When [condition], the system SHALL [observable behavior]."
   - **Document style rules** (critical):
     - Write what the system *is now*, not how it changed. No changelog-style language ("previously", "was changed to", "updated from"). The git diff is the changelog.
     - Do not add version numbers, revision history, or "Version:" fields to internal documents. Git is the version control.
     - Keep rationale sections brief — explain *why*, don't re-describe the system. Reference other docs by ID (REQ-NNN, INT-NNN, UNIT-NNN) instead of duplicating their content.
     - After editing, re-read the document — it should stand alone as the definitive reference.

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

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## Proposed Change

{{PROPOSED_CHANGE}}

## Instructions

1. Read the impact analysis from: `{{ANALYSIS_FOLDER}}/impact.md`

2. Read each document listed as affected (DIRECT, INTERFACE, or DEPENDENT with Action Required of "modify" or "review"). Read them from the `doc/` directories, or from the project root for `ARCHITECTURE.md`.

3. For each affected document, **edit the file directly** with the proposed changes:
   - Make the specific modifications needed to address the proposed change
   - Ensure all cross-references (REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN) remain consistent
   - For verification documents, ensure "Verifies Requirements" and "Verified Design Units" sections reflect the current requirements and design units. Update the Procedure and Expected Results sections if the verified behavior changed.
   - For requirement documents, ensure every requirement uses the condition/response pattern: "When [condition], the system SHALL [observable behavior]."
   - **Document style rules** (critical):
     - Write what the system *is now*, not how it changed. No changelog-style language ("previously", "was changed to", "updated from"). The git diff is the changelog.
     - Do not add version numbers, revision history, or "Version:" fields to internal documents. Git is the version control.
     - Keep rationale sections brief — explain *why*, don't re-describe the system. Reference other docs by ID (REQ-NNN, INT-NNN, UNIT-NNN) instead of duplicating their content.
     - After editing, re-read the document — it should stand alone as the definitive reference.

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

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

Read all modified files listed in `{{ANALYSIS_FOLDER}}/proposed_changes.md` from the `doc/` directories.

Check each modified document for:

1. Requirement statements use condition/response format ("When X, the system SHALL Y")
2. No implementation details in requirements (data layouts, register fields belong in interfaces)
3. Each requirement is singular (not compound)
4. Cross-references (REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN) are valid and consistent
5. For verification documents: "Verifies Requirements" references valid REQ-NNN IDs and "Verified Design Units" references valid UNIT-NNN IDs
6. Changes align with the rationale described in proposed_changes.md

If you find fixable issues, edit the doc files directly to correct them.

Return ONLY this summary:

VALIDATION_SUMMARY_START
Documents reviewed: <n>
Issues found: <n>
Issues corrected: <n>
Issues requiring human review: <n> — <brief descriptions if any>
VALIDATION_SUMMARY_END
__SYSKIT_TEMPLATE_END__

# --- .syskit/prompts/refine-single.md ---
info "Creating .syskit/prompts/refine-single.md"
cat > ".syskit/prompts/refine-single.md" << '__SYSKIT_TEMPLATE_END__'
# Refine Proposed Changes — Subagent Instructions

You are refining previously proposed specification changes based on the user's review feedback.

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## User Feedback

{{FEEDBACK}}

## Affected Files

The following documents may need modification based on the feedback:

{{AFFECTED_FILES}}

## Instructions

1. Read the impact analysis summary from: `{{ANALYSIS_FOLDER}}/impact.md` — read only the `## Summary` section (last ~15 lines) for context.

2. Read the change summary from: `{{ANALYSIS_FOLDER}}/proposed_changes.md` — read the `## Change Summary` table to understand what was originally proposed.

3. Read each file listed in the affected files above from the `doc/` directories (or from the project root for `ARCHITECTURE.md`). These files already contain the proposed changes (uncommitted).

4. Run `git diff -- <file>` for each affected file to see what was changed by the original proposal. This helps you understand the baseline and avoid undoing correct changes.

5. Analyze the user's feedback against the current state of the documents. Determine what specific edits are needed to address the feedback.

6. For each document that needs changes, **edit the file directly**:
   - Make the specific modifications needed to address the user's feedback
   - Preserve correct changes from the original proposal — only modify what the feedback asks for
   - Ensure all cross-references (REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN) remain consistent
   - For verification documents, ensure "Verifies Requirements" and "Verified Design Units" sections reflect the current requirements and design units. Update the Procedure and Expected Results sections if the verified behavior changed.
   - For requirement documents, ensure every requirement uses the condition/response pattern: "When [condition], the system SHALL [observable behavior]."
   - **Document style rules** (critical):
     - Write what the system *is now*, not how it changed. No changelog-style language ("previously", "was changed to", "updated from"). The git diff is the changelog.
     - Do not add version numbers, revision history, or "Version:" fields to internal documents. Git is the version control.
     - Keep rationale sections brief — explain *why*, don't re-describe the system. Reference other docs by ID (REQ-NNN, INT-NNN, UNIT-NNN) instead of duplicating their content.
     - After editing, re-read the document — it should stand alone as the definitive reference.

7. While editing, validate each requirement you modify or create:
   - **Format:** Must use condition/response pattern. If it lacks a trigger condition, add one.
   - **Appropriate Level:** If it specifies data layout, register fields, byte encoding, packet structure, or wire protocol details, flag this — that detail belongs in an interface document.
   - **Singular:** If it addresses multiple capabilities, split it into separate requirements.
   - **Verifiable:** The condition must define a clear test setup and the behavior a clear pass criterion.

8. If the feedback implies changes to documents NOT in your affected files list (e.g., the user's feedback about one document creates a consistency issue with another), note this in the cross-impact section of your summary but do NOT modify documents outside your list.

9. After editing all affected documents, return ONLY this compact response (nothing else):

   REFINE_SUMMARY_START
   Feedback: <one-line summary of the feedback addressed>
   Documents examined: <n>
   Documents edited: <n>
   Files edited: <comma-separated filenames>
   Changes: <one-line per edited file: "filename — brief description of what changed">
   Quality warnings: <n> (<brief list or "None">)
   Cross-impact notes: <any consistency issues with documents outside the affected set, or "None">
   REFINE_SUMMARY_END
__SYSKIT_TEMPLATE_END__

# --- .syskit/ref/cross-references.md ---
info "Creating .syskit/ref/cross-references.md"
cat > ".syskit/ref/cross-references.md" << '__SYSKIT_TEMPLATE_END__'
# Cross-Reference Reference

## Identifiers

- `REQ-001` — Requirement 001 (top-level)
- `REQ-001.03` — Requirement 001, child 03
- `INT-005` — Interface 005 (top-level)
- `INT-005.01` — Interface 005, child 01
- `UNIT-012` — Design unit 012 (top-level)
- `UNIT-012.03` — Design unit 012, child 03
- `VER-007` — Verification 007 (top-level)
- `VER-007.02` — Verification 007, child 02

Identifiers are derived from filenames: `req_001_foo.md` → `REQ-001`, `req_001.03_bar.md` → `REQ-001.03`, `int_005.01_uart.md` → `INT-005.01`, `unit_012.03_pid.md` → `UNIT-012.03`, `ver_007_motor_test.md` → `VER-007`, `ver_007.02_edge_cases.md` → `VER-007.02`

## Hierarchical Numbering

All document types support two-level hierarchy using dot-notation. Child documents use `NNN.NN` to show their parent:

- Top-level: `req_004_motor_control.md` → `REQ-004`
- Child: `req_004.01_voltage_levels.md` → `REQ-004.01`
- Top-level: `int_005_peripheral_bus.md` → `INT-005`
- Child: `int_005.01_uart_registers.md` → `INT-005.01`
- Top-level: `unit_012_control_loop.md` → `UNIT-012`
- Child: `unit_012.03_pid_controller.md` → `UNIT-012.03`
- Top-level: `ver_007_motor_test.md` → `VER-007`
- Child: `ver_007.02_edge_cases.md` → `VER-007.02`

Top-level IDs use 3-digit padding (`NNN`). Children use 2-digit padding (`.NN`). Hierarchy is limited to two levels.

## Bidirectional Links

The following links must be maintained bidirectionally:

- REQ "Allocated To" ↔ UNIT "Implements Requirements"
- REQ "Interfaces" ↔ INT "Referenced By"
- UNIT "Provides" ↔ INT "Parties Provider"
- UNIT "Consumes" ↔ INT "Parties Consumer"
- VER "Verifies Requirements" ↔ REQ "Verified By"
- VER "Verified Design Units" ↔ UNIT "Verification"

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

## Document Style Principles

These apply to all document types (requirements, interfaces, design units):

1. **Documents are the current truth, not a changelog.** Write what the system *is*, not how it evolved. History belongs in git commits and their messages. After editing a document, re-read it — it should stand alone as the definitive reference without any narrative about previous versions.

2. **No version numbers on internal documents.** Internal interfaces, requirements, and design units are versioned by git. Do not add "Version:", "v2", or revision history sections. External interfaces may reference the version of the external specification they describe (e.g., "SPI Mode 0", "PNG 1.2").

3. **Keep rationale sections brief.** Rationale explains *why* a decision was made, not *what* the whole system does. Reference other `doc/` files by ID (REQ-NNN, INT-NNN, UNIT-NNN) rather than re-describing their content.

4. **Cross-reference, don't duplicate.** If information is defined in another document, reference it by ID. Each fact should have one authoritative location.

5. **Be concise.** Documents should be scannable. Prefer tables and lists over prose. Omit filler phrases and obvious context.

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

## Verification (`ver_NNN_<name>.md`)

Verification documents describe HOW a requirement is verified.

- Reference requirements being verified with `REQ-NNN`
- Reference design units being exercised with `UNIT-NNN`
- Link to test implementation files
- Define pass/fail criteria
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

# --- .claude/commands/syskit-approve.md ---
info "Creating .claude/commands/syskit-approve.md"
cat > ".claude/commands/syskit-approve.md" << '__SYSKIT_TEMPLATE_END__'
---
description: Approve or reject proposed specification changes (works across sessions)
arguments:
  - name: analysis
    description: Name of the analysis folder (optional, uses most recent if not specified)
    required: false
---

# Approve Specification Changes

You are reviewing and approving (or rejecting) proposed specification changes from a previous `/syskit-propose` or `/syskit-refine` session.

## Instructions

### Step 0: Context Check

If this conversation already contains output from a previous syskit command (look for any `*_SUMMARY` markers or previous `/syskit-*` command invocations), STOP and tell the user:

"Start a fresh conversation to run `/syskit-approve` — all progress is saved to disk and will be picked up automatically."

If the user explicitly included `--continue` in their command, skip this check and proceed.

### Step 1: Find Pending Changes

If `$ARGUMENTS.analysis` is provided:

- Find the analysis folder: `.syskit/analysis/$ARGUMENTS.analysis/`

Otherwise:

- Find the most recent folder in `.syskit/analysis/`

Check that `proposed_changes.md` exists in the folder. If not, tell the user:

"No proposed changes found. Run `/syskit-propose` first to generate specification changes."

Read the first ~10 lines of `proposed_changes.md` to get the change name and status.

If `Status:` is already "Approved", tell the user:

"These changes have already been approved. Run `/syskit-plan` to create an implementation task breakdown."

If `Status:` is not "Pending Approval", tell the user the current status and suggest running `/syskit-propose`.

### Step 2: Check for Uncommitted Changes

Run `git status -- doc/ ARCHITECTURE.md` to verify there are uncommitted changes in the doc directory or ARCHITECTURE.md.

If there are **no** uncommitted changes:

Tell the user: "No uncommitted changes found in `doc/` or `ARCHITECTURE.md`. The proposed changes may have already been committed or reverted. Check `git log -- doc/` for recent commits, or re-run `/syskit-propose` to regenerate changes."

### Step 3: Show Change Summary

Read the change summary table from `proposed_changes.md` (the `## Change Summary` section, typically a markdown table).

Run `git diff --stat -- doc/ ARCHITECTURE.md` to get a compact summary of what files changed.

Present to the user:

"**Pending approval:** <change name>
**Analysis folder:** `.syskit/analysis/<folder>/`

**Change summary:**
<paste the change summary table from proposed_changes.md>

**Files changed:**
<paste git diff --stat output>

Review the full diff with `git diff doc/ ARCHITECTURE.md` or your editor's source control panel.

Reply with:
- **'approve'** to accept all changes and proceed to planning
- **'approve \<filename\>'** to keep changes to specific file(s) and revert others
- **'reject'** to revert all changes (`git checkout -- doc/ ARCHITECTURE.md`)
- **'refine'** to describe issues and run `/syskit-refine` instead"

### Step 4: Handle Response

- **approve:** Update `Status: Pending Approval` to `Status: Approved` in `.syskit/analysis/<folder>/proposed_changes.md`. Proceed to Step 5.
- **approve \<filename\>:** Revert all other changed doc files with `git checkout -- doc/<other files>`, keeping only the specified file(s). Update `Status: Pending Approval` to `Status: Approved` in `proposed_changes.md`. Proceed to Step 5.
- **reject:** Run `git checkout -- doc/ ARCHITECTURE.md` to revert all changes. Tell the user the proposal has been discarded.
- **refine:** Tell the user to start a new conversation and run `/syskit-refine --feedback "<their feedback>"` to iterate on the changes.

### Step 5: Next Steps

Tell the user:

"Changes approved. Status updated in `.syskit/analysis/<folder>/proposed_changes.md`.

Next step: run `/syskit-plan` to create an implementation task breakdown. You can run it right here in this conversation or start a new one."
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

List all files in `doc/requirements/`, `doc/interfaces/`, `doc/design/`, and `doc/verification/`.

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
4. **`doc/verification/`** — How requirements are verified. Each file is a verification procedure (VER-NNN).
5. **`.syskit/`** — Tooling: scripts, manifest, working folders for analysis and tasks.

Explain the naming convention:
- `req_001_motor_control.md` → referenced as `REQ-001`
- `req_001.01_torque_limit.md` → referenced as `REQ-001.01` (child of REQ-001)
- `int_002_spi_bus.md` → referenced as `INT-002`
- `int_002.01_uart_registers.md` → referenced as `INT-002.01` (child of INT-002)
- `unit_003_pwm_driver.md` → referenced as `UNIT-003`
- `unit_003.01_pid_controller.md` → referenced as `UNIT-003.01` (child of UNIT-003)
- `ver_004_motor_test.md` → referenced as `VER-004`
- `ver_004.01_edge_cases.md` → referenced as `VER-004.01` (child of VER-004)

Explain that all document types support two-level hierarchy — child documents use dot-notation (e.g., `REQ-001.03`, `INT-002.01`, `UNIT-003.01`) so the parent relationship is visible from the ID itself.

Explain that these documents cross-reference each other to create a traceability web:
- Requirements reference the interfaces they use, the design units that implement them, and the verifications that prove them
- Design units reference the requirements they satisfy and the interfaces they provide or consume
- Verification documents reference the requirements they verify and the design units they exercise

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

Then explain the change workflow for future changes:

1. **`/syskit-impact`** — Describe a change; syskit analyzes which specs are affected
2. **`/syskit-propose`** — Draft proposed modifications to affected specs
3. **`/syskit-refine`** — (Optional, repeatable) Fix issues in proposed changes based on your review feedback
4. **`/syskit-approve`** — Approve changes when ready (works across sessions — review overnight if needed)
5. **`/syskit-plan`** — Break approved spec changes into implementation tasks
6. **`/syskit-implement`** — Execute tasks one by one with verification

Tell the user: "You're set up. When you want to make a change, start with `/syskit-impact` and describe what you want to change."

---

## Path B: Existing Project

### Step 2B: Overview

Provide a brief inventory of existing documents:

1. Count and list documents by type:
   - **Requirements:** List each file's ID and title (e.g., `REQ-001: Motor Control`)
   - **Interfaces:** List each file's ID and title (e.g., `INT-001: SPI Bus`)
   - **Design Units:** List each file's ID and title (e.g., `UNIT-001: PWM Driver`)
   - **Verification:** List each file's ID and title (e.g., `VER-001: Motor Test`)
2. Note any special documents present: `states_and_modes.md`, `quality_metrics.md`, `design_decisions.md`, `concept_of_execution.md`, `test_strategy.md`

### Step 3B: Explain the Structure

Explain the conventions this project uses:

1. **Naming:** `req_NNN_name.md` → `REQ-NNN`, `int_NNN_name.md` → `INT-NNN`, `unit_NNN_name.md` → `UNIT-NNN`, `ver_NNN_name.md` → `VER-NNN` (children use dot-notation: `req_NNN.NN_name.md` → `REQ-NNN.NN`, `int_NNN.NN_name.md` → `INT-NNN.NN`, `unit_NNN.NN_name.md` → `UNIT-NNN.NN`, `ver_NNN.NN_name.md` → `VER-NNN.NN`)
2. **Cross-references:** Documents link to each other using these IDs to create traceability:
   - Requirements → Interfaces they use, Design Units that implement them, Verifications that prove them
   - Design Units → Requirements they satisfy, Interfaces they provide/consume
   - Verifications → Requirements they verify, Design Units they exercise
3. **Manifest:** `.syskit/manifest.md` stores SHA256 hashes for freshness checking between workflow steps

### Step 4B: Explain the Change Workflow

Walk through how to make changes in this project:

1. **`/syskit-impact <description>`** — Start here. Describe what you want to change. Syskit analyzes which specs are affected and creates an impact report.
2. **`/syskit-propose`** — Drafts specific edits to affected specs. You review using `git diff`.
3. **`/syskit-refine --feedback "<issues>"`** — (Optional) Fix issues in the proposal based on your review. Repeatable.
4. **`/syskit-approve`** — Approve changes when satisfied. Works across sessions — review overnight if needed.
5. **`/syskit-plan`** — Creates an implementation task breakdown from approved spec changes.
6. **`/syskit-implement`** — Executes tasks one by one with verification.

Also mention helper scripts for creating new documents:
- `.syskit/scripts/new-req.sh <name>` — Create a new requirement (use `--parent REQ-NNN` for child)
- `.syskit/scripts/new-int.sh <name>` — Create a new interface (use `--parent INT-NNN` for child)
- `.syskit/scripts/new-unit.sh <name>` — Create a new design unit (use `--parent UNIT-NNN` for child)
- `.syskit/scripts/new-ver.sh <name>` — Create a new verification (use `--parent VER-NNN` for child)

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
    description: Description of the proposed change (not needed for --incremental)
    required: false
  - name: incremental
    description: "Re-run impact analysis acknowledging already-approved refinements (flag, no value needed)"
    required: false
---

# Impact Analysis

You are analyzing the impact of a proposed change on this project's specifications.

## Proposed Change

$ARGUMENTS.change

## Instructions

### Step 0: Context Check

If this conversation already contains output from a previous syskit command (look for any `*_SUMMARY` markers or previous `/syskit-*` command invocations), STOP and tell the user:

"Impact analysis should start in a fresh conversation. All progress is saved to disk and will be picked up automatically."

If the user explicitly included `--continue` in their command, skip this check and proceed.

### Step 1: Read Manifest

Read `.syskit/manifest.md` to get the current list of all specification documents and their hashes.

Count the total number of specification documents listed (excluding any with `_000_template` in the name). You will use this count to validate the subagent's output.

### Step 1.5: Check for Incremental Mode

If `$ARGUMENTS.incremental` is provided (or the user's command included `--incremental`):

1. Find the most recent analysis folder in `.syskit/analysis/`.

2. Read the first few lines of `impact.md` in that folder to get the original proposed change description.

3. Set the PROPOSED_CHANGE to the original change description from impact.md, appended with:
   "NOTE: Specifications may have been modified since the original analysis (via `/syskit-propose` and `/syskit-refine`). The impact analysis should reflect the CURRENT state of all documents."

4. Rename the existing `impact.md` to `impact_prev.md` (for reference).

5. Note the analysis folder path — you will reuse it. Skip Step 2.

If `$ARGUMENTS.incremental` is NOT provided and `$ARGUMENTS.change` is empty, STOP and tell the user: "Please provide a change description: `/syskit-impact \"your change description\"`"

### Step 2: Create Analysis Folder

**Skip this step if in incremental mode (Step 1.5 was executed).**

Create the analysis folder: `.syskit/analysis/{{DATE}}_<change_name>/`

Also create a draft staging directory: `.syskit/analysis/_draft/`

### Step 3: Delegate Document Analysis

Use the Task tool to launch a subagent that reads and analyzes all specification documents. This keeps the full document contents out of your context window.

Launch a `general-purpose` Task agent with **model: sonnet** and this prompt (substitute the actual proposed change for PROPOSED_CHANGE, and the analysis folder path for ANALYSIS_FOLDER):

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

Run: `.syskit/scripts/manifest-snapshot.sh .syskit/analysis/<folder>/`

If NOT in incremental mode, clean up the draft staging directory:

```bash
rm -rf .syskit/analysis/_draft/
```

### Step 6: Next Step

Present the summary counts to the user.

**If in incremental mode**, also show a comparison: "Previous analysis had \<n\> documents affected. After refinement: \<n\> documents now affected."

Tell the user:

"Impact analysis complete. Results saved to `.syskit/analysis/<folder>/impact.md`.

Next step: run `/syskit-propose` to propose specification changes based on this analysis. You can run it right here in this conversation or start a new one."
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

If this conversation already contains output from a previous syskit command (look for any `*_SUMMARY` markers or previous `/syskit-*` command invocations), STOP and tell the user:

"Each implementation task needs its own fresh conversation to avoid context pollution between tasks. All progress is saved to disk and will be picked up automatically."

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

Also remind to update any design or verification documents if implementation details changed the behavior of verified requirements or design units.
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

Check if this conversation already contains output from a previous syskit command (look for any `*_SUMMARY` markers or previous `/syskit-*` command invocations).

**Allowed transitions:** `/syskit-plan` may run in the same conversation after any of these commands complete with approval:
- `/syskit-propose` (after the user approved inline)
- `/syskit-refine` (after the user approved inline)
- `/syskit-approve` (after the user approved)

These are natural workflow continuations — the user just approved changes and wants to proceed to planning.

**Blocked transitions:** If the conversation contains IMPACT_SUMMARY, IMPLEMENT_SUMMARY, or PLAN_SUMMARY markers (indicating heavy prior context or a repeated plan attempt), STOP and tell the user:

"Start a fresh conversation to run `/syskit-plan` — all progress is saved to disk and will be picked up automatically."

If the user explicitly included `--continue` in their command, skip this check and proceed.

### Step 1: Load Approved Changes

If `$ARGUMENTS.analysis` is provided:

- Find the analysis folder: `.syskit/analysis/$ARGUMENTS.analysis/`

Otherwise:

- Find the most recent folder in `.syskit/analysis/`

Check for approval status:

1. Check that `proposed_changes.md` exists in the folder.
   - If it does not exist, tell the user: "No proposed changes found. Run `/syskit-propose` first to generate specification changes."

2. Read ONLY its first ~10 lines. Check the `Status:` line.
   - If "Approved", proceed.
   - If "Pending Approval", tell the user: "Proposed changes have not been approved yet. Run `/syskit-approve` to review and approve them, or approve inline during `/syskit-propose`."
   - If any other status, tell the user the current status and suggest re-running `/syskit-propose`.

Note the analysis folder path and the change name — you will pass these to the subagent.

### Step 2: Delegate Scope Extraction

Use the Task tool to launch a subagent that reads the affected documents and design units to extract implementation scope. This keeps the full document contents out of your context window.

The subagent reads all needed files from disk — do NOT embed proposed_changes.md content in the prompt.

Launch a `general-purpose` Task agent with **model: sonnet** and this prompt (substitute ANALYSIS_FOLDER and TASK_FOLDER):

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

Check if this conversation already contains output from a previous syskit command (look for any `*_SUMMARY` markers or previous `/syskit-*` command invocations).

**Allowed transitions:** `/syskit-propose` may run in the same conversation after `/syskit-impact` completes (IMPACT_SUMMARY is the only marker present). This is a natural workflow continuation.

**Blocked transitions:** If the conversation contains PROPOSE_SUMMARY, CHUNK_SUMMARY, PLAN_SUMMARY, IMPLEMENT_SUMMARY, or REFINE_SUMMARY markers, STOP and tell the user:

"Start a fresh conversation to run `/syskit-propose` — all progress is saved to disk and will be picked up automatically."

If the user explicitly included `--continue` in their command, skip this check and proceed.

### Step 1: Check Git Status

Run `git status -- doc/ ARCHITECTURE.md` to check for uncommitted changes in the doc directory or ARCHITECTURE.md.

If there are uncommitted changes, **stop and tell the user:**

"There are uncommitted changes in `doc/` or `ARCHITECTURE.md`. Please commit or stash them before running `/syskit-propose`, so that proposed changes can be reviewed with `git diff` and reverted cleanly if needed."

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

Launch a `general-purpose` Task agent with **model: sonnet** and this prompt (substitute ANALYSIS_FOLDER and PROPOSED_CHANGE):

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

For each chunk, launch a `general-purpose` Task agent with **model: sonnet** and this prompt (substitute ANALYSIS_FOLDER, PROPOSED_CHANGE, CHUNK_NUMBER, and ASSIGNED_FILES):

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

If the change set affects 5 or more documents, launch a validation Task agent with **model: haiku**:

> Read your full instructions from `.syskit/prompts/propose-validate.md`.
>
> Use this value for placeholders in the prompt file:
> - `{{ANALYSIS_FOLDER}}`: ANALYSIS_FOLDER
>
> Follow the instructions in the prompt file. Return ONLY the compact summary described at the end.

The subagent will return a summary in `VALIDATION_SUMMARY_START`/`VALIDATION_SUMMARY_END` format.

### Step 7: Present Changes for Review

Tell the user:

"Proposed changes have been applied directly to the doc files. Review the changes using `git diff doc/ ARCHITECTURE.md` or the VSCode source control panel.

**Summary:**
<paste the change summary table from the subagent's returned summary>

**Quality warnings:** <list any, or 'None'>

Reply with:
- **'approve'** to keep all changes and proceed to planning
- **'approve \<filename\>'** to keep changes to a specific file and revert others
- **'revise \<filename\>'** to discuss modifications to a specific file
- **'reject'** to revert all changes (`git checkout -- doc/ ARCHITECTURE.md`)

Or review at your leisure and use these commands in a new session:
- **`/syskit-refine --feedback \"<your feedback>\"`** to iterate on the proposed changes
- **`/syskit-approve`** to approve when ready"

### Step 8: Handle Approval

- **approve:** Update `Status: Pending Approval` to `Status: Approved` in `.syskit/analysis/<folder>/proposed_changes.md`. Proceed to Step 9.
- **approve \<filename\>:** Revert all other files with `git checkout -- doc/<other files>`, keep the specified file(s). Update `Status: Pending Approval` to `Status: Approved` in `.syskit/analysis/<folder>/proposed_changes.md`. Proceed to Step 9.
- **revise \<filename\>:** Discuss the specific file with the user, make adjustments, then re-present.
- **reject:** Run `git checkout -- doc/ ARCHITECTURE.md` to revert all changes. Tell the user the proposal has been discarded.

### Step 9: Next Steps

After applying approved changes, tell the user:

"Changes approved. Summary saved to `.syskit/analysis/<folder>/proposed_changes.md`.

Next step: run `/syskit-plan` to create an implementation task breakdown. You can run it right here in this conversation or start a new one."
__SYSKIT_TEMPLATE_END__

# --- .claude/commands/syskit-refine.md ---
info "Creating .claude/commands/syskit-refine.md"
cat > ".claude/commands/syskit-refine.md" << '__SYSKIT_TEMPLATE_END__'
---
description: Refine proposed specification changes based on review feedback
arguments:
  - name: feedback
    description: "Description of what needs to change in the proposed specifications (e.g., 'INT-002 should use CAN instead of SPI', 'REQ-003 also needs to cover error recovery')"
    required: true
  - name: analysis
    description: Name of the analysis folder (optional, uses most recent if not specified)
    required: false
---

# Refine Proposed Changes

You are refining previously proposed specification changes based on the user's review feedback. This command iterates on changes from `/syskit-propose` — fixing issues, adjusting decisions, or addressing gaps the user identified during review.

## Instructions

### Step 0: Context Check

If this conversation already contains output from a previous syskit command (look for any `*_SUMMARY` markers or previous `/syskit-*` command invocations), STOP and tell the user:

"Refine needs a fresh conversation to cleanly re-read your current doc state. All progress is saved to disk and will be picked up automatically."

If the user explicitly included `--continue` in their command, skip this check and proceed.

### Step 1: Check for Pending Proposed Changes

Run `git status -- doc/ ARCHITECTURE.md` to check for uncommitted changes in the doc directory or ARCHITECTURE.md.

If there are **no** uncommitted changes, **stop and tell the user:**

"No uncommitted changes found in `doc/` or `ARCHITECTURE.md`. Run `/syskit-propose` first to generate specification changes, then use `/syskit-refine` to iterate on them."

### Step 2: Load the Analysis Context

If `$ARGUMENTS.analysis` is provided:

- Find the analysis folder: `.syskit/analysis/$ARGUMENTS.analysis/`

Otherwise:

- Find the most recent folder in `.syskit/analysis/`

Check that `proposed_changes.md` exists. If not, warn the user that the uncommitted doc changes may not be from a syskit proposal.

Read the first ~10 lines of `proposed_changes.md` to get the change name and status. If `Status:` is "Approved", warn the user:

"These changes have already been approved. Running refine will modify approved specifications. Continue? (yes/no)"

Read ONLY the `## Change Summary` table from `proposed_changes.md` to get the list of affected filenames and change descriptions.

Also read ONLY the `## Summary` section from `impact.md` (the last ~15 lines) to get the impact context.

Note the analysis folder path — you will pass it to the subagent.

### Step 3: Determine Affected Files

From the user's feedback (`$ARGUMENTS.feedback`), identify which documents are likely affected:

1. Look for explicit document references (REQ-NNN, INT-NNN, UNIT-NNN, or filenames)
2. Match against the change summary table to identify relevant files
3. If the feedback is broad or doesn't reference specific documents, include all documents from the change summary

Run `git diff --name-only -- doc/ ARCHITECTURE.md` to get the list of files with uncommitted changes. Cross-reference with the feedback to build the final list of files the subagent should examine and potentially modify.

### Step 4: Delegate Refinement

Count the affected documents.

**8 or fewer documents:** Launch a single subagent.

Launch a `general-purpose` Task agent with **model: sonnet** and this prompt (substitute ANALYSIS_FOLDER, FEEDBACK, and AFFECTED_FILES with actual values):

> Read your full instructions from `.syskit/prompts/refine-single.md`.
>
> Use these values for placeholders in the prompt file:
> - `{{FEEDBACK}}`: FEEDBACK
> - `{{ANALYSIS_FOLDER}}`: ANALYSIS_FOLDER
> - `{{AFFECTED_FILES}}`: AFFECTED_FILES (the list of specific filenames to examine and potentially modify)
>
> Follow the instructions in the prompt file. Return ONLY the compact summary described at the end.

The subagent will return a summary in `REFINE_SUMMARY_START`/`REFINE_SUMMARY_END` format.

**More than 8 documents:** Use the same chunked approach — launch multiple subagents each handling a subset of the affected files, passing the full feedback to each. Launch all chunk agents in parallel. After all complete, assemble results.

### Step 5: Validate Refinement

After the subagent(s) return:

1. Parse the summary to verify which documents were edited
2. Note any quality warnings reported
3. If the subagent failed or returned incomplete results, tell the user and offer to re-run

### Step 6: Present Changes for Review

Run `git diff --stat -- doc/ ARCHITECTURE.md` to get the updated change summary.

Tell the user:

"Refinement applied based on your feedback. Review the updated changes using `git diff doc/ ARCHITECTURE.md` or the VSCode source control panel.

**Feedback addressed:**
$ARGUMENTS.feedback

**Documents modified in this refinement:** \<n\>
**Summary:**
\<paste the change summary from the subagent's returned summary\>

**Quality warnings:** \<list any, or 'None'\>

Reply with:
- **'approve'** to accept all changes (updates status and proceeds to planning)
- **'approve \<filename\>'** to keep changes to specific file(s) and revert others
- **'reject'** to revert ALL changes including the original proposal (`git checkout -- doc/ ARCHITECTURE.md`)
- **Further feedback** to describe additional issues (will require another `/syskit-refine` run in a new session)

Or review at your leisure and run `/syskit-approve` in a new session when ready."

### Step 7: Handle Response

- **approve:** Update `Status: Pending Approval` to `Status: Approved` in `.syskit/analysis/<folder>/proposed_changes.md`. Proceed to Step 8.
- **approve \<filename\>:** Revert non-specified files with `git checkout -- doc/<other files>`, keep the specified file(s). Update Status to "Approved". Proceed to Step 8.
- **reject:** Run `git checkout -- doc/ ARCHITECTURE.md` to revert all changes (including the original proposal). Tell the user the changes have been discarded.
- **Further feedback:** Tell the user to start a new conversation and run `/syskit-refine --feedback "<their new feedback>"`.

### Step 8: Next Steps

Tell the user:

"Changes approved. Status updated in `.syskit/analysis/<folder>/proposed_changes.md`.

Next step: run `/syskit-plan` to create an implementation task breakdown. You can run it right here in this conversation or start a new one."
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

### Documentation principle

- **Reference, don't reproduce.** Don't duplicate definitions, requirements, or design descriptions — reference the authoritative source instead. For project documents, reference by ID (`REQ-NNN`, `INT-NNN`, `UNIT-NNN`, `VER-NNN`). For external standards, reference by name, version/year, and section number (e.g., "IEEE 802.3-2022 §4.2.1", "RFC 9293 §3.1"). This applies to specification documents and code comments alike.

### Making changes

For non-trivial changes affecting system behavior, use the syskit workflow:

1. `/syskit-impact <change>` — Analyze what specifications are affected
2. `/syskit-propose` — Propose specification updates
3. `/syskit-refine --feedback "<issues>"` — Iterate on proposed changes based on review feedback (optional, repeatable)
4. `/syskit-approve` — Approve changes (works across sessions, enables overnight review)
5. `/syskit-plan` — Break into implementation tasks
6. `/syskit-implement` — Execute with traceability

New to syskit? Run `/syskit-guide` for an interactive walkthrough.

### Reference

- Specifications: `doc/requirements/`, `doc/interfaces/`, `doc/design/`, `doc/verification/`
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

## Verified By

- VER-NNN (<verification name>)

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
- **Child interfaces:** `int_NNN.NN_<name>.md` — dot-notation encodes parent (e.g., `int_005.01_uart_registers.md`)
- **Create new:** `.syskit/scripts/new-int.sh <name>` or `.syskit/scripts/new-int.sh --parent INT-NNN <name>`
- **Cross-references:** Use `INT-NNN` or `INT-NNN.NN` identifiers (derived from filename)
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
- **Child units:** `unit_NNN.NN_<name>.md` — dot-notation encodes parent (e.g., `unit_002.01_pid_controller.md`)
- **Create new:** `.syskit/scripts/new-unit.sh <name>` or `.syskit/scripts/new-unit.sh --parent UNIT-NNN <name>`
- **Cross-references:** Use `UNIT-NNN` or `UNIT-NNN.NN` identifiers (derived from filename)
- **Traceability:** Source files link back via `Spec-ref` comments; use `impl-stamp.sh` to keep hashes current

## Framework Documents

- **concept_of_execution.md** — System runtime behavior, startup, data flow, and event handling
- **design_decisions.md** — Architecture Decision Records (ADR format)

## Table of Contents

<!-- TOC-START -->
*Run `.syskit/scripts/toc-update.sh` to generate.*
<!-- TOC-END -->
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/design/ARCHITECTURE.md ---
info "Creating .syskit/templates/doc/design/ARCHITECTURE.md"
cat > ".syskit/templates/doc/design/ARCHITECTURE.md" << '__SYSKIT_TEMPLATE_END__'
# Architecture

*Architecture overview for <system name>*

## System Description

<Describe the system at the highest level: what problem it solves, its primary
responsibilities, and its operational environment.>

## Design Philosophy

<Key architectural principles guiding the design: e.g., "data-flow driven",
"layered", "hardware abstraction via interfaces", etc.>

## Component Interactions

<Narrative description of how major components collaborate. Reference specific
units (UNIT-NNN) and interfaces (INT-NNN) where helpful.>

---

<!-- syskit-arch-start -->
*Run `.syskit/scripts/arch-update.sh` to generate.*
<!-- syskit-arch-end -->
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/verification/ver_000_template.md ---
info "Creating .syskit/templates/doc/verification/ver_000_template.md"
cat > ".syskit/templates/doc/verification/ver_000_template.md" << '__SYSKIT_TEMPLATE_END__'
# VER-000: Template

This is a template file. Create new verification documents using:

```bash
.syskit/scripts/new-ver.sh <verification_name>
```

Or copy this template and modify.

---

## Verification Method

Choose one:
- **Test:** Verified by executing a test procedure
- **Analysis:** Verified by technical evaluation
- **Inspection:** Verified by examination
- **Demonstration:** Verified by operation

## Verifies Requirements

- REQ-NNN (<requirement name>)

List all requirements this verification procedure covers.

## Verified Design Units

- UNIT-NNN (<unit name>)

List all design units exercised by this verification.

## Preconditions

<What must be true before this verification can be executed>

- System state, configuration, or environment required
- Dependencies on other verifications completing first
- Required test data or fixtures

## Procedure

<Step-by-step verification procedure>

1. <Step 1>
2. <Step 2>
3. ...

For automated tests, describe what the test does at a level useful for understanding intent, not line-by-line code walkthrough.

## Expected Results

<What constitutes a pass>

- **Pass Criteria:** <observable outcome that means the requirement is satisfied>
- **Fail Criteria:** <observable outcome that means the requirement is NOT satisfied>

## Test Implementation

- `<test filepath>`: <description of what this test file does>

List all test source files that implement this verification.

## Notes

<Additional context, edge cases, known limitations of this verification>
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/verification/test_strategy.md ---
info "Creating .syskit/templates/doc/verification/test_strategy.md"
cat > ".syskit/templates/doc/verification/test_strategy.md" << '__SYSKIT_TEMPLATE_END__'
# Test Strategy

This document records the cross-cutting verification strategy: frameworks, tools, approaches, and coverage goals that apply across all verification documents.

## Test Frameworks and Tools

### <Framework/Tool Name>

- **Type:** Unit Test | Integration Test | System Test | Static Analysis
- **Language/Platform:** <applicable language or platform>
- **Usage:** <what it is used for>
- **Configuration:** <where configuration lives, e.g., config file path>

## Test Approaches

### Approval Testing

- **Description:** <how approval testing is used in this project>
- **Tool:** <approval testing tool>
- **Approved files location:** <path to approved files>

### <Other Approach>

- **Description:** <description of the approach>
- **Applicable to:** <which types of requirements or components>

## Coverage Goals

### Requirement Coverage

- **Target:** 100% of SHALL requirements have at least one VER-NNN
- **Measurement:** Traceability analysis via `trace-sync.sh`

### Code Coverage

- **Target:** <percentage>
- **Tool:** <coverage tool>
- **Exclusions:** <what is excluded from coverage measurement>

### Branch Coverage

- **Target:** <percentage>
- **Measurement:** <tool>

## Test Environments

### <Environment Name>

- **Description:** <what this environment is>
- **Purpose:** <what types of tests run here>
- **Setup:** <how to set up or access>

## Test Execution

### CI/CD Integration

- **Pipeline:** <where tests run in CI>
- **Triggers:** <what triggers test execution>
- **Reporting:** <how results are reported>

### Manual Testing

- **When Required:** <conditions requiring manual testing>
- **Procedure:** <how manual tests are documented and tracked>

## Test Data Management

- **Strategy:** <how test data is created, maintained, and versioned>
- **Location:** <where test data lives>
__SYSKIT_TEMPLATE_END__

# --- .syskit/templates/doc/verification/README.md ---
info "Creating .syskit/templates/doc/verification/README.md"
cat > ".syskit/templates/doc/verification/README.md" << '__SYSKIT_TEMPLATE_END__'
# Verification

*Software Verification Description (SVD) for <system name>*

This directory contains the verification specifications — the authoritative record of **how** the system's requirements are verified.

## System Overview

<Brief description of the system: what it is, what it does, and its operational context.>

## Document Description

<Brief overview of what this document covers and how it is organized.>

## Purpose

Each verification document describes a test or analysis procedure that demonstrates a requirement is satisfied. Verification documents link back to requirements (`REQ-NNN`) and design units (`UNIT-NNN`), completing the traceability chain from requirement through design to test.

Verification methods:

- **Test** — Verified by executing a test procedure with defined pass/fail criteria
- **Analysis** — Verified by technical evaluation (calculation, simulation, modeling)
- **Inspection** — Verified by examination of design artifacts
- **Demonstration** — Verified by operating the system under specified conditions

## Conventions

- **Naming:** `ver_NNN_<name>.md` — 3-digit zero-padded number, lowercase, underscores
- **Child verifications:** `ver_NNN.NN_<name>.md` — dot-notation encodes parent (e.g., `ver_003.01_edge_cases.md`)
- **Create new:** `.syskit/scripts/new-ver.sh <name>` or `.syskit/scripts/new-ver.sh --parent VER-NNN <name>`
- **Cross-references:** Use `VER-NNN` or `VER-NNN.NN` identifiers (derived from filename)
- **Traceability:** Each verification document references the requirements it verifies

## Framework Documents

- **test_strategy.md** — Cross-cutting test strategy: frameworks, tools, coverage goals, and approaches

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
cp .syskit/templates/doc/verification/ver_000_template.md doc/verification/ver_000_template.md

# Framework docs: only create if missing
for tmpl in \
    "doc/requirements/quality_metrics.md" \
    "doc/requirements/states_and_modes.md" \
    "doc/design/concept_of_execution.md" \
    "doc/design/design_decisions.md" \
    "doc/requirements/README.md" \
    "doc/interfaces/README.md" \
    "doc/design/README.md" \
    "doc/verification/test_strategy.md" \
    "doc/verification/README.md"
do
    if [ ! -f "$tmpl" ]; then
        info "Creating $tmpl"
        cp ".syskit/templates/$tmpl" "$tmpl"
    else
        info "Skipping $tmpl (already exists)"
    fi
done

# ARCHITECTURE.md: only create if missing (user-owned after initial install)
if [ ! -f "ARCHITECTURE.md" ]; then
    info "Creating ARCHITECTURE.md"
    cp ".syskit/templates/doc/design/ARCHITECTURE.md" "ARCHITECTURE.md"
else
    info "Skipping ARCHITECTURE.md (already exists)"
fi

# Update table of contents in README files
info "Updating doc README table of contents..."
.syskit/scripts/toc-update.sh

# Update architecture diagram if ARCHITECTURE.md has guard markers
if grep -q '<!-- syskit-arch-start -->' "ARCHITECTURE.md" 2>/dev/null; then
    info "Updating ARCHITECTURE.md diagram..."
    .syskit/scripts/arch-update.sh
fi

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
info "To allow Claude Code to run syskit scripts without prompting,"
info "add this to .claude/settings.local.json under permissions.allow:"
info ""
echo '  "Bash(.syskit/scripts/*:*)"'
info ""
info "See .syskit/AGENTS.md for full documentation."
