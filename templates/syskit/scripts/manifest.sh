#!/bin/bash
# Generate manifest of all specification documents with SHA256 hashes
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$PROJECT_ROOT/.syskit/manifest.md"

cd "$PROJECT_ROOT"

cat > "$MANIFEST" << 'HEADER'
# Specification Manifest

This file tracks the SHA256 hashes of all specification documents.
Used for freshness checking in impact analysis and task planning.

HEADER

echo "Generated: $(date -Iseconds)" >> "$MANIFEST"
echo "" >> "$MANIFEST"

# Function to hash files in a directory
hash_directory() {
    local dir=$1
    local title=$2
    
    echo "## $title" >> "$MANIFEST"
    echo "" >> "$MANIFEST"
    
    if [ ! -d "$dir" ]; then
        echo "*No files*" >> "$MANIFEST"
        echo "" >> "$MANIFEST"
        return
    fi
    
    local files=$(find "$dir" -name "*.md" -type f 2>/dev/null | sort)
    
    if [ -z "$files" ]; then
        echo "*No files*" >> "$MANIFEST"
        echo "" >> "$MANIFEST"
        return
    fi
    
    echo "| File | SHA256 | Modified |" >> "$MANIFEST"
    echo "|------|--------|----------|" >> "$MANIFEST"
    
    for f in $files; do
        # Get relative path from project root
        local relpath="${f#$PROJECT_ROOT/}"
        
        # Get SHA256 (compatible with both Linux and macOS)
        if command -v sha256sum &> /dev/null; then
            local hash=$(sha256sum "$f" | cut -c1-16)
        else
            local hash=$(shasum -a 256 "$f" | cut -c1-16)
        fi
        
        # Get modification date
        if [[ "$OSTYPE" == "darwin"* ]]; then
            local mod=$(stat -f "%Sm" -t "%Y-%m-%d" "$f")
        else
            local mod=$(date -r "$f" +%Y-%m-%d)
        fi
        
        echo "| $relpath | \`$hash\` | $mod |" >> "$MANIFEST"
    done
    
    echo "" >> "$MANIFEST"
}

hash_directory "doc/requirements" "Requirements"
hash_directory "doc/interfaces" "Interfaces"
hash_directory "doc/design" "Design"

echo "Manifest updated: $MANIFEST"
