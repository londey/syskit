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
            if [ "$CHILD_NUM" -ge "$NEXT_CHILD" ]; then
                NEXT_CHILD=$((CHILD_NUM + 1))
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
            if [ "$NUM" -ge "$NEXT_NUM" ]; then
                NEXT_NUM=$((NUM + 1))
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
