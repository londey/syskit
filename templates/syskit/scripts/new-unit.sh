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
