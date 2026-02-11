#!/bin/bash
# Update the Table of Contents in each doc/*/README.md
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Update TOC in a single README.md
# Scans sibling .md files, extracts H1 headings, writes a linked list
update_toc() {
    local dir=$1
    local readme="$dir/README.md"

    if [ ! -f "$readme" ]; then
        return
    fi

    # Check for TOC markers
    if ! grep -q '<!-- TOC-START -->' "$readme"; then
        return
    fi

    # Collect entries: "filename|heading"
    local entries=""
    for f in $(find "$dir" -maxdepth 1 -name "*.md" -type f | LC_COLLATE=C sort); do
        local base=$(basename "$f")

        # Skip README itself and 000 templates
        case "$base" in
            README.md|*_000_template.md) continue ;;
        esac

        # Extract H1 heading (first line starting with "# ")
        local heading=$(grep -m1 '^# ' "$f" | sed 's/^# //')
        if [ -z "$heading" ]; then
            heading="$base"
        fi

        entries="${entries}${base}|${heading}\n"
    done

    # Build replacement block
    local toc_block=""
    if [ -z "$entries" ]; then
        toc_block="*No documents yet.*"
    else
        while IFS='|' read -r base heading; do
            [ -z "$base" ] && continue
            toc_block="${toc_block}- [${heading}](${base})\n"
        done < <(printf "$entries")
    fi

    # Replace content between TOC markers
    # Strategy: print before START, print new TOC, skip until END, print after END
    local tmp="${readme}.tmp"
    awk -v toc="$toc_block" '
    /<!-- TOC-START -->/ {
        print
        # Print the toc content using printf-style interpretation
        n = split(toc, lines, "\\n")
        for (i = 1; i <= n; i++) {
            if (lines[i] != "") print lines[i]
        }
        skip = 1
        next
    }
    /<!-- TOC-END -->/ {
        skip = 0
        print
        next
    }
    !skip { print }
    ' "$readme" > "$tmp"

    mv "$tmp" "$readme"
}

update_toc "doc/requirements"
update_toc "doc/interfaces"
update_toc "doc/design"

echo "TOC updated in doc/*/README.md"
