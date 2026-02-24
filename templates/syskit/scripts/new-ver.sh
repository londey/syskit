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
            if [ "$CHILD_NUM" -ge "$NEXT_CHILD" ]; then
                NEXT_CHILD=$((CHILD_NUM + 1))
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
            if [ "$NUM" -ge "$NEXT_NUM" ]; then
                NEXT_NUM=$((NUM + 1))
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
