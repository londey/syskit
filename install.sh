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

PROJECT_NAME=$(basename "$(pwd)")
DATE=$(date -Iseconds)

info "Installing syskit in: $(pwd)"

# Create directory structure
info "Creating directories..."
mkdir -p doc/requirements
mkdir -p doc/interfaces
mkdir -p doc/design
mkdir -p .syskit/commands
mkdir -p .syskit/scripts
mkdir -p .syskit/analysis
mkdir -p .syskit/tasks
mkdir -p .claude/commands


# --- .syskit/AGENTS.md ---
info "Creating .syskit/AGENTS.md"
cat > ".syskit/AGENTS.md" << 'SYSKIT_EOF'
# syskit — AI Assistant Instructions

This project uses syskit for specification-driven development.

## Document Locations

All persistent engineering documents live under `doc/`:

- `doc/requirements/` — What the system must do
- `doc/interfaces/` — Contracts between components and with external systems
- `doc/design/` — How the system accomplishes requirements

Working documents live under `.syskit/`:

- `.syskit/analysis/` — Impact analysis results (ephemeral)
- `.syskit/tasks/` — Implementation task plans (ephemeral)
- `.syskit/manifest.md` — SHA256 hashes of all doc files

## Document Types

### Requirements (`req_NNN_<name>.md`)

Requirements state WHAT the system must do, not HOW.

- Use SHALL for mandatory requirements
- Use SHOULD for recommended requirements  
- Use MAY for optional requirements
- Each requirement should be testable/verifiable
- Reference interfaces with `INT-NNN`
- Allocate to design units with `UNIT-NNN`

### Interfaces (`int_NNN_<name>.md`)

Interfaces define contracts. They may be:

- **Internal:** Defined by this project (register maps, packet formats, internal APIs)
- **External:** Defined elsewhere (PNG format, SPI protocol, USB spec)

For external interfaces, document:
- The external specification and version
- How this system uses/constrains it
- What subset of features are supported

For internal interfaces, the document IS the specification.

### Design Units (`unit_NNN_<name>.md`)

Design units describe HOW a piece of the system works.

- Reference requirements being implemented with `REQ-NNN`
- Reference interfaces being implemented/consumed with `INT-NNN`
- Document internal interfaces to other units
- Link to implementation files in `src/`

## Workflows

### Before Making Changes

Always run impact analysis first:

1. Load all documents from `doc/` into context
2. Analyze which documents are affected by the proposed change
3. Categorize as DIRECT, DEPENDENT, or INTERFACE impact
4. Check manifest for any documents modified since last analysis

### Proposing Changes

1. Create analysis folder: `.syskit/analysis/<date>_<change_name>/`
2. Write `impact.md` listing affected documents with rationale
3. Write `snapshot.md` with SHA256 of each referenced document
4. Write `proposed_changes.md` with specific modifications to each affected document
5. Wait for human approval before modifying `doc/` files

### Planning Implementation

After spec changes are approved and applied:

1. Create task folder: `.syskit/tasks/<date>_<change_name>/`
2. Write `plan.md` with implementation strategy
3. Write individual `task_NNN_<name>.md` files for each discrete task
4. Include `snapshot.md` referencing current doc hashes
5. Tasks should be small enough to implement and verify independently

### Implementing

1. Work through tasks in order
2. After each task, verify against relevant requirements
3. Update design unit documents if implementation details change
4. Run `.syskit/scripts/manifest.sh` after doc changes

## Freshness Checking

Analysis and task files include SHA256 snapshots of referenced documents.

When loading previous analysis or tasks:

1. Compare snapshot hashes against current manifest
2. Flag any documents that have changed:
   - ✓ unchanged — analysis still valid for this document
   - ⚠ modified — review if changes affect analysis
   - ✗ deleted — analysis references removed document
3. If critical documents changed, recommend re-running analysis

## File Numbering

When creating new documents:

- Find highest existing number in that category
- Use next number with 3-digit padding: `001`, `002`, etc.
- Use `_` separator, lowercase, no spaces in names
- Examples: `req_001_system_overview.md`, `int_003_register_map.md`

Or use the helper scripts:

```bash
.syskit/scripts/new-req.sh <name>
.syskit/scripts/new-int.sh <name>  
.syskit/scripts/new-unit.sh <name>
```

## Cross-References

Use consistent identifiers when referencing between documents:

- `REQ-001` — Requirement 001
- `REQ-001.3` — Third sub-requirement of requirement 001
- `INT-005` — Interface 005
- `UNIT-012` — Design unit 012

These identifiers are derived from filenames: `req_001_foo.md` → `REQ-001`
SYSKIT_EOF

# --- .syskit/scripts/manifest.sh ---
info "Creating .syskit/scripts/manifest.sh"
cat > ".syskit/scripts/manifest.sh" << 'SYSKIT_EOF'
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
SYSKIT_EOF
chmod +x ".syskit/scripts/manifest.sh"

# --- .syskit/scripts/new-int.sh ---
info "Creating .syskit/scripts/new-int.sh"
cat > ".syskit/scripts/new-int.sh" << 'SYSKIT_EOF'
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
SYSKIT_EOF
chmod +x ".syskit/scripts/new-int.sh"

# --- .syskit/scripts/new-req.sh ---
info "Creating .syskit/scripts/new-req.sh"
cat > ".syskit/scripts/new-req.sh" << 'SYSKIT_EOF'
#!/bin/bash
# Create a new requirement document
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REQ_DIR="$PROJECT_ROOT/doc/requirements"

NAME=$1

if [ -z "$NAME" ]; then
    echo "Usage: new-req.sh <requirement_name>"
    echo "Example: new-req.sh spi_interface"
    exit 1
fi

# Sanitize name: lowercase, replace spaces/hyphens with underscores
NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

mkdir -p "$REQ_DIR"

# Find next available number
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

if [ -f "$FILEPATH" ]; then
    echo "Error: $FILEPATH already exists"
    exit 1
fi

cat > "$FILEPATH" << EOF
# $ID: $(echo "$NAME" | tr '_' ' ' | sed 's/\b\(.\)/\u\1/g')

## Classification

- **Priority:** Essential | Important | Nice-to-have
- **Stability:** Stable | Evolving | Volatile
- **Verification:** Test | Analysis | Inspection | Demonstration

## Requirement

The system SHALL ...

## Rationale

<Why this requirement exists>

## Parent Requirements

- None

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
SYSKIT_EOF
chmod +x ".syskit/scripts/new-req.sh"

# --- .syskit/scripts/new-unit.sh ---
info "Creating .syskit/scripts/new-unit.sh"
cat > ".syskit/scripts/new-unit.sh" << 'SYSKIT_EOF'
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
SYSKIT_EOF
chmod +x ".syskit/scripts/new-unit.sh"

# --- .claude/commands/syskit-guide.md ---
info "Creating .claude/commands/syskit-guide.md"
cat > ".claude/commands/syskit-guide.md" << 'SYSKIT_EOF'
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
- `int_002_spi_bus.md` → referenced as `INT-002`
- `unit_003_pwm_driver.md` → referenced as `UNIT-003`

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
   - **Requirement statement:** Help them write a clear SHALL/SHOULD/MAY statement
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

1. **Naming:** `req_NNN_name.md` → `REQ-NNN`, `int_NNN_name.md` → `INT-NNN`, `unit_NNN_name.md` → `UNIT-NNN`
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
SYSKIT_EOF

# --- .claude/commands/syskit-impact.md ---
info "Creating .claude/commands/syskit-impact.md"
cat > ".claude/commands/syskit-impact.md" << 'SYSKIT_EOF'
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

### Step 1: Load All Documents

Read all files in:
- `doc/requirements/`
- `doc/interfaces/`
- `doc/design/`

Also read `.syskit/manifest.md` for current file hashes.

### Step 2: Analyze Each Document

For each document, determine if it would be affected by the proposed change.

Categorize impacts as:

- **DIRECT**: The document itself describes something being changed
- **INTERFACE**: The document defines or uses an interface affected by the change
- **DEPENDENT**: The document depends on something being changed (via REQ/INT/UNIT references)
- **UNAFFECTED**: The document is not impacted (state why)

### Step 3: Create Analysis Folder

Create `.syskit/analysis/{{DATE}}_<change_name>/` with:

1. `impact.md` — The impact report (format below)
2. `snapshot.md` — SHA256 of each analyzed document from manifest

### Step 4: Output Impact Report

Use this format for `impact.md`:

```markdown
# Impact Analysis: <brief change summary>

Created: <timestamp>
Status: Pending Review

## Proposed Change

<detailed description of the change>

## Direct Impacts

### <filename>
- **ID:** <REQ/INT/UNIT-NNN>
- **Impact:** <what specifically is affected>
- **Action Required:** <modify/review/no change>

## Interface Impacts

### <filename>
- **ID:** <INT-NNN>
- **Impact:** <what specifically is affected>
- **Consumers:** <list of units that consume this interface>
- **Providers:** <list of units that provide this interface>
- **Action Required:** <modify/review/no change>

## Dependent Impacts

### <filename>
- **ID:** <REQ/INT/UNIT-NNN>
- **Dependency:** <what it depends on that is changing>
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
...
```

### Step 5: Ask for Confirmation

After presenting the impact report, ask:

"Shall I proceed with proposing specific modifications to the affected documents?"
SYSKIT_EOF

# --- .claude/commands/syskit-implement.md ---
info "Creating .claude/commands/syskit-implement.md"
cat > ".claude/commands/syskit-implement.md" << 'SYSKIT_EOF'
---
description: Execute implementation tasks from the current plan
arguments:
  - name: task
    description: Task number to implement (optional, continues from current or starts at 1)
    required: false
---

# Implement Task

You are implementing tasks from the current implementation plan.

## Instructions

### Step 1: Load Task Plan

Find the most recent folder in `.syskit/tasks/` and load:
- `plan.md` — Overall plan
- `snapshot.md` — Document state at planning time

If `$ARGUMENTS.task` is provided:
- Load `task_$ARGUMENTS.task_*.md` (matching the number prefix)

Otherwise:
- Find the first task with Status: Pending
- Or if all complete, report completion

### Step 2: Check Freshness

Compare snapshot hashes against `.syskit/manifest.md`:

- If referenced specifications changed, warn user
- Changes to specs may invalidate the task plan
- Recommend re-running `/syskit-plan` if changes are significant

### Step 3: Check Dependencies

Verify all dependency tasks are complete:

- If dependencies are pending, prompt user to complete them first
- Or offer to implement the dependency task instead

### Step 4: Load Context

Load all files listed in the task's "Files to Modify" and "Specification References" sections.

Understand:
- What the specification requires
- What the current implementation looks like
- What changes are needed

### Step 5: Implement

Follow the task's implementation steps:

1. Make the changes described
2. Explain each change as you make it
3. Ensure changes align with referenced specifications

### Step 6: Verify

Work through the task's verification checklist:

1. For each verification criterion, confirm it is met
2. If a criterion cannot be verified, note why
3. Run any specified tests

### Step 7: Update Task Status

Update the task file:

```markdown
Status: Complete
Completed: <timestamp>
```

Add a completion summary:

```markdown
## Completion Notes

<What was actually done, any deviations from plan>

## Verification Results

- [x] <criterion> — <result>
- [x] <criterion> — <result>
```

### Step 8: Next Steps

After completing the task:

1. Check if there are more pending tasks
2. If yes, ask: "Task <n> complete. Proceed to Task <next>?"
3. If no, report: "All tasks complete. Run `.syskit/scripts/manifest.sh` to update the manifest."

Also remind to update any design documents if implementation details changed.
SYSKIT_EOF

# --- .claude/commands/syskit-plan.md ---
info "Creating .claude/commands/syskit-plan.md"
cat > ".claude/commands/syskit-plan.md" << 'SYSKIT_EOF'
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

### Step 1: Load Approved Changes

If `$ARGUMENTS.analysis` is provided:
- Load `.syskit/analysis/$ARGUMENTS.analysis/proposed_changes.md`

Otherwise:
- Find the most recent folder in `.syskit/analysis/`
- Load `proposed_changes.md` from that folder

Verify the status shows changes were approved. If not, prompt user to run `/syskit-propose` first.

### Step 2: Load Current Specifications

Load all affected documents from `doc/` to understand the current state.

Also load relevant design unit documents to understand implementation structure.

### Step 3: Identify Implementation Scope

For each specification change, identify:

1. Which source files need modification
2. Which tests need modification or creation
3. Dependencies between changes (what must be done first)
4. Verification method for each change

### Step 4: Create Task Folder

Create `.syskit/tasks/<date>_<change_name>/` with:

1. `plan.md` — Overall implementation strategy
2. `snapshot.md` — SHA256 of relevant documents at planning time
3. `task_001_<n>.md` through `task_NNN_<n>.md` — Individual tasks

### Step 5: Write Implementation Plan

Create `plan.md`:

```markdown
# Implementation Plan: <change name>

Based on: ../.syskit/analysis/<folder>/proposed_changes.md
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

### Step 6: Write Individual Tasks

For each task, create `task_NNN_<n>.md`:

```markdown
# Task NNN: <task name>

Status: Pending
Dependencies: <list or "None">
Specification References: <REQ-NNN, INT-NNN, UNIT-NNN>

## Objective

<What this task accomplishes>

## Files to Modify

- `<filepath>`: <what changes>
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

### Step 7: Present Plan

Output the implementation plan summary and ask:

"Implementation plan created with <n> tasks. 

Ready to begin implementation?
- 'start' to begin with Task 1
- 'start <n>' to begin with a specific task
- 'review <n>' to discuss a specific task
- 'revise' to modify the plan"
SYSKIT_EOF

# --- .claude/commands/syskit-propose.md ---
info "Creating .claude/commands/syskit-propose.md"
cat > ".claude/commands/syskit-propose.md" << 'SYSKIT_EOF'
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

### Step 1: Load the Impact Analysis

If `$ARGUMENTS.analysis` is provided:
- Load `.syskit/analysis/$ARGUMENTS.analysis/impact.md`
- Load `.syskit/analysis/$ARGUMENTS.analysis/snapshot.md`

Otherwise:
- Find the most recent folder in `.syskit/analysis/`
- Load `impact.md` and `snapshot.md` from that folder

### Step 2: Check Freshness

Compare snapshot hashes against `.syskit/manifest.md`:

- If any affected documents have changed since analysis, warn the user
- Recommend re-running impact analysis if changes are significant
- Proceed with caution if user confirms

### Step 3: Load Affected Documents

Load the full content of all documents marked as affected in the impact analysis.

### Step 4: Propose Changes

For each affected document, propose specific modifications:

1. Show the relevant current content
2. Explain what needs to change and why
3. Show the proposed new content
4. Note any ripple effects to other documents

### Step 5: Write Proposed Changes

Create/update `.syskit/analysis/<folder>/proposed_changes.md`:

```markdown
# Proposed Changes: <change name>

Based on: impact.md
Created: <timestamp>
Status: Pending Approval

## Document: <filename>

### Current Content (relevant section)

```
<current content>
```

### Proposed Content

```
<proposed content>
```

### Rationale

<why this change is needed>

### Ripple Effects

- <any effects on other documents>

---

## Document: <next filename>

...

---

## Change Summary

| Document | Type | Change Description |
|----------|------|-------------------|
| <filename> | Modify | <brief description> |
| <filename> | Add Section | <brief description> |
| <filename> | Remove | <brief description> |

## Approval Checklist

- [ ] Requirements changes reviewed
- [ ] Interface changes reviewed
- [ ] Design changes reviewed
- [ ] No unintended impacts identified
- [ ] Ready to apply changes
```

### Step 6: Request Approval

Present a summary of all proposed changes and ask:

"Please review the proposed changes above. Reply with:
- 'approve' to apply all changes
- 'approve <filename>' to apply changes to a specific file
- 'revise <filename>' to discuss modifications
- 'reject' to discard this proposal"
SYSKIT_EOF

# --- doc/requirements/quality_metrics.md ---
if [ ! -f "doc/requirements/quality_metrics.md" ]; then
info "Creating doc/requirements/quality_metrics.md"
cat > "doc/requirements/quality_metrics.md" << 'SYSKIT_EOF'
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
SYSKIT_EOF
else
    info "Skipping doc/requirements/quality_metrics.md (already exists)"
fi

# --- doc/requirements/req_000_template.md ---
if [ ! -f "doc/requirements/req_000_template.md" ]; then
info "Creating doc/requirements/req_000_template.md"
cat > "doc/requirements/req_000_template.md" << 'SYSKIT_EOF'
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

The system SHALL ...

Use:
- **SHALL** for mandatory requirements
- **SHOULD** for recommended requirements
- **MAY** for optional requirements

## Rationale

<Why this requirement exists. What problem does it solve? What drives this need?>

## Parent Requirements

- REQ-NNN (<parent requirement name>)
- Or "None" if this is a top-level requirement

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
SYSKIT_EOF
else
    info "Skipping doc/requirements/req_000_template.md (already exists)"
fi

# --- doc/requirements/states_and_modes.md ---
if [ ! -f "doc/requirements/states_and_modes.md" ]; then
info "Creating doc/requirements/states_and_modes.md"
cat > "doc/requirements/states_and_modes.md" << 'SYSKIT_EOF'
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
SYSKIT_EOF
else
    info "Skipping doc/requirements/states_and_modes.md (already exists)"
fi

# --- doc/interfaces/int_000_template.md ---
if [ ! -f "doc/interfaces/int_000_template.md" ]; then
info "Creating doc/interfaces/int_000_template.md"
cat > "doc/interfaces/int_000_template.md" << 'SYSKIT_EOF'
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
SYSKIT_EOF
else
    info "Skipping doc/interfaces/int_000_template.md (already exists)"
fi

# --- doc/design/concept_of_execution.md ---
if [ ! -f "doc/design/concept_of_execution.md" ]; then
info "Creating doc/design/concept_of_execution.md"
cat > "doc/design/concept_of_execution.md" << 'SYSKIT_EOF'
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
SYSKIT_EOF
else
    info "Skipping doc/design/concept_of_execution.md (already exists)"
fi

# --- doc/design/design_decisions.md ---
if [ ! -f "doc/design/design_decisions.md" ]; then
info "Creating doc/design/design_decisions.md"
cat > "doc/design/design_decisions.md" << 'SYSKIT_EOF'
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
SYSKIT_EOF
else
    info "Skipping doc/design/design_decisions.md (already exists)"
fi

# --- doc/design/unit_000_template.md ---
if [ ! -f "doc/design/unit_000_template.md" ]; then
info "Creating doc/design/unit_000_template.md"
cat > "doc/design/unit_000_template.md" << 'SYSKIT_EOF'
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
SYSKIT_EOF
else
    info "Skipping doc/design/unit_000_template.md (already exists)"
fi

# Generate initial manifest
info "Generating manifest..."
.syskit/scripts/manifest.sh

# Create/update CLAUDE.md to reference syskit
if [ -f "CLAUDE.md" ]; then
    if ! grep -q "syskit" "CLAUDE.md"; then
        info "Adding syskit reference to CLAUDE.md"
        echo "" >> CLAUDE.md
        echo "## syskit" >> CLAUDE.md
        echo "" >> CLAUDE.md
        echo "This project uses syskit for specification-driven development." >> CLAUDE.md
        echo "See \`.syskit/AGENTS.md\` for workflow instructions." >> CLAUDE.md
    fi
else
    info "Creating CLAUDE.md"
    cat > CLAUDE.md << 'CLAUDE_EOF'
# Project Instructions

## syskit

This project uses syskit for specification-driven development.
See `.syskit/AGENTS.md` for workflow instructions.
CLAUDE_EOF
fi

info ""
info "syskit installed successfully!"
info ""
info "Next steps:"
info "  1. Create requirements:  .syskit/scripts/new-req.sh <name>"
info "  2. Create interfaces:    .syskit/scripts/new-int.sh <name>"
info "  3. Create design units:  .syskit/scripts/new-unit.sh <name>"
info "  4. Use /syskit-impact to analyze changes"
info ""
info "See .syskit/AGENTS.md for full documentation."
