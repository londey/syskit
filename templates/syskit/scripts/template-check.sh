#!/bin/bash
# Check document conformance against current templates
# Usage: template-check.sh [--type req|int|unit|framework] [file]
#   No arguments: full scan, generates .syskit/template-status.md
#   --type TYPE: filter to one document type
#   Single file: check just that file, stdout only
# Exit codes: 0 = all conformant, 1 = non-conformant documents found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$PROJECT_ROOT/.syskit/templates/doc"
REPORT="$PROJECT_ROOT/.syskit/template-status.md"

cd "$PROJECT_ROOT"

# Require bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: bash 4+ required (found ${BASH_VERSION})" >&2
    exit 1
fi

# ─── Argument parsing ─────────────────────────────────────────────

TYPE_FILTER=""
FILE_FILTER=""

while [ $# -gt 0 ]; do
    case "$1" in
        --type)
            TYPE_FILTER="$2"
            shift 2
            ;;
        *)
            FILE_FILTER="$1"
            shift
            ;;
    esac
done

if [ -n "$TYPE_FILTER" ]; then
    case "$TYPE_FILTER" in
        req|int|unit|ver|framework) ;;
        *)
            echo "Error: --type must be req, int, unit, ver, or framework" >&2
            exit 1
            ;;
    esac
fi

# ─── Template mapping ─────────────────────────────────────────────

# Returns the template path for a given document file, or empty if no template applies
template_for() {
    local file="$1"
    local base
    base=$(basename "$file")

    # Skip templates themselves and READMEs
    [[ "$base" == *_000_template* ]] && return
    [[ "$base" == "README.md" ]] && return

    # Numbered documents
    if [[ "$base" =~ ^req_[0-9] ]]; then
        echo "$TEMPLATE_DIR/requirements/req_000_template.md"
    elif [[ "$base" =~ ^int_[0-9] ]]; then
        echo "$TEMPLATE_DIR/interfaces/int_000_template.md"
    elif [[ "$base" =~ ^unit_[0-9] ]]; then
        echo "$TEMPLATE_DIR/design/unit_000_template.md"
    elif [[ "$base" =~ ^ver_[0-9] ]]; then
        echo "$TEMPLATE_DIR/verification/ver_000_template.md"
    # Framework docs — matched by exact name
    elif [ -f "$TEMPLATE_DIR/requirements/$base" ]; then
        echo "$TEMPLATE_DIR/requirements/$base"
    elif [ -f "$TEMPLATE_DIR/interfaces/$base" ]; then
        echo "$TEMPLATE_DIR/interfaces/$base"
    elif [ -f "$TEMPLATE_DIR/design/$base" ]; then
        echo "$TEMPLATE_DIR/design/$base"
    elif [ -f "$TEMPLATE_DIR/verification/$base" ]; then
        echo "$TEMPLATE_DIR/verification/$base"
    fi
}

# Returns the type category for a document file
doc_type() {
    local base
    base=$(basename "$1")
    if [[ "$base" =~ ^req_ ]]; then echo "req"
    elif [[ "$base" =~ ^int_ ]]; then echo "int"
    elif [[ "$base" =~ ^unit_ ]]; then echo "unit"
    elif [[ "$base" =~ ^ver_ ]]; then echo "ver"
    else echo "framework"
    fi
}

# ─── Section extraction from template ─────────────────────────────

# Extract required heading lines from a template file
# For numbered templates: skip preamble above first ---
# Returns heading lines like "## Classification", "### Provides"
extract_headings() {
    local tmpl="$1"
    local base
    base=$(basename "$tmpl")
    local skip_preamble=false

    # Numbered templates have a preamble above ---
    if [[ "$base" == *_000_template* ]]; then
        skip_preamble=true
    fi

    awk -v skip="$skip_preamble" '
        BEGIN { past_sep = (skip == "false") ? 1 : 0 }
        !past_sep && /^---[[:space:]]*$/ { past_sep = 1; next }
        past_sep && /^##+ / { print }
    ' "$tmpl"
}

# ─── Collect documents to check ───────────────────────────────────

declare -a DOC_FILES=()

collect_docs() {
    local f base tmpl dtype

    if [ -n "$FILE_FILTER" ]; then
        # Single file mode
        if [ ! -f "$FILE_FILTER" ]; then
            echo "Error: file not found: $FILE_FILTER" >&2
            exit 1
        fi
        DOC_FILES+=("$FILE_FILTER")
        return
    fi

    # Scan doc directories
    for dir in doc/requirements doc/interfaces doc/design doc/verification; do
        [ -d "$dir" ] || continue
        for f in "$dir"/*.md; do
            [ -f "$f" ] || continue
            base=$(basename "$f")
            [[ "$base" == "README.md" ]] && continue
            [[ "$base" == *_000_template* ]] && continue

            # Apply type filter
            if [ -n "$TYPE_FILTER" ]; then
                dtype=$(doc_type "$f")
                [ "$dtype" != "$TYPE_FILTER" ] && continue
            fi

            # Only include if a template exists for this file
            tmpl=$(template_for "$f")
            [ -z "$tmpl" ] && continue
            [ -f "$tmpl" ] || continue

            DOC_FILES+=("$f")
        done
    done

    # Also check ARCHITECTURE.md at project root if it has a template
    if [ -z "$TYPE_FILTER" ] || [ "$TYPE_FILTER" = "framework" ]; then
        if [ -f "ARCHITECTURE.md" ] && [ -f "$TEMPLATE_DIR/design/ARCHITECTURE.md" ]; then
            DOC_FILES+=("ARCHITECTURE.md")
        fi
    fi
}

# ─── Check a single document against its template ─────────────────

# Populates MISSING_HEADINGS array for the given file
declare -a MISSING_HEADINGS=()

check_doc() {
    local doc="$1"
    local tmpl
    tmpl=$(template_for "$doc")
    MISSING_HEADINGS=()

    if [ -z "$tmpl" ] || [ ! -f "$tmpl" ]; then
        return
    fi

    local heading
    while IFS= read -r heading; do
        [ -z "$heading" ] && continue
        # Check if this heading exists in the document (exact line match)
        if ! grep -qFx "$heading" "$doc"; then
            MISSING_HEADINGS+=("$heading")
        fi
    done < <(extract_headings "$tmpl")
}

# ─── Main scan ─────────────────────────────────────────────────────

collect_docs

CONFORMANT_COUNT=0
NONCONFORMANT_COUNT=0

# "relpath|missing1;missing2;..." for each non-conformant doc
declare -a RESULT_LINES=()
declare -a CONFORMANT_FILES=()

for doc in $(printf '%s\n' "${DOC_FILES[@]}" | LC_COLLATE=C sort); do
    check_doc "$doc"

    if [ ${#MISSING_HEADINGS[@]} -eq 0 ]; then
        CONFORMANT_COUNT=$((CONFORMANT_COUNT + 1))
        CONFORMANT_FILES+=("$doc")
    else
        NONCONFORMANT_COUNT=$((NONCONFORMANT_COUNT + 1))
        missing_str=$(printf '%s;' "${MISSING_HEADINGS[@]}")
        missing_str="${missing_str%;}"  # trim trailing ;
        RESULT_LINES+=("${doc}|${missing_str}")
    fi
done

# ─── Report generation ─────────────────────────────────────────────

generate_report() {
    local out="/dev/stdout"
    if [ -z "$FILE_FILTER" ]; then
        out="$REPORT"
    fi

    {
        echo "# Template Conformance Status"
        echo ""
        echo "Generated: $(date -Iseconds 2>/dev/null || date)"
        echo ""
        echo "## Summary"
        echo ""
        echo "- Conformant: $CONFORMANT_COUNT"
        echo "- Non-conformant: $NONCONFORMANT_COUNT"
        echo ""

        if [ ${#RESULT_LINES[@]} -gt 0 ]; then
            echo "## Non-Conformant Documents"
            echo ""

            local entry doc_path missing_str tmpl tmpl_base
            for entry in "${RESULT_LINES[@]}"; do
                doc_path="${entry%%|*}"
                missing_str="${entry##*|}"
                tmpl=$(template_for "$doc_path")
                tmpl_base=$(basename "$tmpl")

                echo "### $doc_path"
                echo ""
                echo "Template: \`$tmpl_base\`"
                echo ""

                IFS=';' read -ra headings <<< "$missing_str"
                local h
                for h in "${headings[@]}"; do
                    echo "- Missing: \`$h\`"
                done
                echo ""
            done
        fi
    } > "$out"

    if [ -z "$FILE_FILTER" ]; then
        echo "Report written: $REPORT"
    fi
}

# ─── Stdout summary ────────────────────────────────────────────────

print_summary() {
    local doc
    for doc in "${CONFORMANT_FILES[@]}"; do
        echo "✓ conformant     — $doc"
    done

    local entry doc_path missing_str
    for entry in "${RESULT_LINES[@]}"; do
        doc_path="${entry%%|*}"
        missing_str="${entry##*|}"
        echo "⚠ non-conformant — $doc_path"

        IFS=';' read -ra headings <<< "$missing_str"
        local h
        for h in "${headings[@]}"; do
            echo "    missing: $h"
        done
    done
}

# ─── Output ────────────────────────────────────────────────────────

if [ ${#DOC_FILES[@]} -eq 0 ]; then
    echo "No documents found to check."
    exit 0
fi

if [ -z "$FILE_FILTER" ]; then
    generate_report
    echo ""
fi

print_summary

echo ""
TOTAL=$((CONFORMANT_COUNT + NONCONFORMANT_COUNT))

if [ "$NONCONFORMANT_COUNT" -eq 0 ]; then
    echo "All $TOTAL documents conform to current templates."
else
    echo "Summary: $CONFORMANT_COUNT conformant, $NONCONFORMANT_COUNT non-conformant out of $TOTAL documents"
fi

exit $((NONCONFORMANT_COUNT > 0 ? 1 : 0))
