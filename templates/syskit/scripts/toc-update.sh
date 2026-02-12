#!/bin/bash
# Update the Table of Contents in each doc/*/README.md
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Explicit ordering for non-numbered framework files per directory.
# Files listed here appear first in the TOC, in this order.
# Any non-numbered file NOT listed gets appended alphabetically after these.
framework_order() {
    case "$1" in
        *requirements) echo "states_and_modes.md quality_metrics.md" ;;
        *design)       echo "design_decisions.md concept_of_execution.md" ;;
        *)             echo "" ;;
    esac
}

# Update TOC in a single README.md
# Scans sibling .md files, extracts H1 headings, writes a linked list
# Ordering: explicitly ordered framework files, then remaining framework
# files alphabetically, then numbered spec files alphabetically.
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

    local explicit_order
    explicit_order=$(framework_order "$dir")

    # Collect entries into two groups: framework (non-numbered) and numbered
    local numbered_entries=""
    local framework_entries=""

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

        local entry="${base}|${heading}\n"

        # Classify: numbered spec files vs framework files
        case "$base" in
            req_[0-9][0-9][0-9]*.md | unit_[0-9][0-9][0-9]*.md | int_[0-9][0-9][0-9]*.md)
                numbered_entries="${numbered_entries}${entry}"
                ;;
            *)
                framework_entries="${framework_entries}${entry}"
                ;;
        esac
    done

    # Order framework entries: explicit order first, then alphabetical remainder
    local ordered_framework=""

    for explicit_file in $explicit_order; do
        local match
        match=$(printf "$framework_entries" | grep "^${explicit_file}|" || true)
        if [ -n "$match" ]; then
            ordered_framework="${ordered_framework}${match}\n"
        fi
    done

    # Append any framework files not in the explicit order list
    if [ -n "$framework_entries" ]; then
        while IFS='|' read -r base heading; do
            [ -z "$base" ] && continue
            local already_listed=false
            for explicit_file in $explicit_order; do
                if [ "$base" = "$explicit_file" ]; then
                    already_listed=true
                    break
                fi
            done
            if [ "$already_listed" = false ]; then
                ordered_framework="${ordered_framework}${base}|${heading}\n"
            fi
        done < <(printf "$framework_entries")
    fi

    # Combine: framework first, then numbered
    local all_entries="${ordered_framework}${numbered_entries}"

    # Build replacement block
    local toc_block=""
    if [ -z "$all_entries" ]; then
        toc_block="*No documents yet.*"
    else
        while IFS='|' read -r base heading; do
            [ -z "$base" ] && continue
            toc_block="${toc_block}- [${heading}](${base})\n"
        done < <(printf "$all_entries")
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
