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

When [condition/trigger], the system SHALL [observable behavior/response].

<!-- Format: When [condition], the system SHALL/SHOULD/MAY [behavior].
     Each requirement must have a testable trigger and observable outcome.
     Describe capabilities/behaviors, not data layout or encoding.
     For struct fields, byte formats, protocols → use an interface (INT-NNN). -->

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
