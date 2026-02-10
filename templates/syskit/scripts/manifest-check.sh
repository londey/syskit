#!/bin/bash
# Check freshness of a snapshot against current file hashes
# Usage: manifest-check.sh <snapshot-file>
# Exit codes: 0 = all fresh, 1 = stale or deleted files found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SNAPSHOT="${1:-}"

if [ -z "$SNAPSHOT" ]; then
    echo "Usage: manifest-check.sh <snapshot-file>" >&2
    exit 1
fi

if [ ! -f "$SNAPSHOT" ]; then
    echo "Error: snapshot not found: $SNAPSHOT" >&2
    exit 1
fi

# Determine hash command (Linux vs macOS)
if command -v sha256sum &> /dev/null; then
    hash_cmd() { sha256sum "$1" | cut -c1-16; }
else
    hash_cmd() { shasum -a 256 "$1" | cut -c1-16; }
fi

STALE=0

echo "# Freshness Check"
echo ""
echo "Snapshot: $SNAPSHOT"
echo ""

while IFS='|' read -r _ file hash _; do
    file=$(echo "$file" | xargs)
    hash=$(echo "$hash" | sed 's/`//g' | xargs)

    filepath="$PROJECT_ROOT/$file"

    if [ ! -f "$filepath" ]; then
        echo "✗ deleted  — $file"
        STALE=1
    else
        current=$(hash_cmd "$filepath")
        if [ "$hash" = "$current" ]; then
            echo "✓ unchanged — $file"
        else
            echo "⚠ modified  — $file"
            STALE=1
        fi
    fi
done < <(grep '^| doc/' "$SNAPSHOT")

if [ "$STALE" -eq 0 ]; then
    echo ""
    echo "All documents are fresh."
else
    echo ""
    echo "Some documents have changed since the snapshot was taken."
fi

exit $STALE
