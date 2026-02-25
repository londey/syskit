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
