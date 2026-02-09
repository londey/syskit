#!/bin/bash
# Generate a snapshot.md capturing current SHA256 hashes of specified doc files
# Usage: manifest-snapshot.sh <output-dir> [file1 file2 ...]
#   If no files specified, snapshots all files listed in the manifest
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$PROJECT_ROOT/.syskit/manifest.md"

OUTPUT_DIR="${1:-.}"
shift 2>/dev/null || true

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

cat > "$SNAPSHOT" << EOF
# Document Snapshot

Captured: $(date -Iseconds)

| File | SHA256 |
|------|--------|
EOF

if [ $# -gt 0 ]; then
    # Snapshot specified files
    for file in "$@"; do
        filepath="$PROJECT_ROOT/$file"
        if [ -f "$filepath" ]; then
            hash=$(hash_cmd "$filepath")
            echo "| $file | \`$hash\` |" >> "$SNAPSHOT"
        else
            echo "Warning: file not found: $file" >&2
        fi
    done
else
    # Snapshot all files from the manifest
    if [ ! -f "$MANIFEST" ]; then
        echo "Error: no files specified and manifest not found at $MANIFEST" >&2
        echo "Run .syskit/scripts/manifest.sh first, or specify files explicitly" >&2
        exit 1
    fi

    cd "$PROJECT_ROOT"
    grep '^| doc/' "$MANIFEST" | while IFS='|' read -r _ file _ _; do
        file=$(echo "$file" | xargs)
        if [ -f "$file" ]; then
            hash=$(hash_cmd "$file")
            echo "| $file | \`$hash\` |" >> "$SNAPSHOT"
        fi
    done
fi

echo "Snapshot written: $SNAPSHOT"
