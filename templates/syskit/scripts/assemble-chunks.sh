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
