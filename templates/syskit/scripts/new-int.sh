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
