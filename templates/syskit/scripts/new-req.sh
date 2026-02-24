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

## Verified By

- VER-NNN (<verification name>)

## Notes

<Additional context>
EOF

echo "Created: $FILEPATH"
echo "ID: $ID"
