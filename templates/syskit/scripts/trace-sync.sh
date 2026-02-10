#!/bin/bash
# Check and optionally fix bidirectional cross-references between spec documents
# Usage: trace-sync.sh [--fix]
# Exit codes: 0 = all consistent, 1 = issues found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

REQ_DIR="$PROJECT_ROOT/doc/requirements"
INT_DIR="$PROJECT_ROOT/doc/interfaces"
UNIT_DIR="$PROJECT_ROOT/doc/design"

FIX_MODE=false
[ "${1:-}" = "--fix" ] && FIX_MODE=true

# Require bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: bash 4+ required (found ${BASH_VERSION})" >&2
    exit 1
fi

# ─── ID Map ────────────────────────────────────────────────────────

declare -A ID_TO_FILE    # ID -> full file path
declare -A ID_TO_NAME    # ID -> human-readable name from H1
declare -A ALL_IDS       # ID -> 1

build_id_map() {
    local tag dir prefix entry base num id name
    for entry in "req:$REQ_DIR:REQ" "int:$INT_DIR:INT" "unit:$UNIT_DIR:UNIT"; do
        IFS=':' read -r tag dir prefix <<< "$entry"
        [ -d "$dir" ] || continue
        for f in "$dir"/${tag}_[0-9][0-9][0-9]_*.md; do
            [ -f "$f" ] || continue
            base=$(basename "$f")
            [[ "$base" == *_000_template* ]] && continue
            num=$(echo "$base" | sed "s/${tag}_\([0-9][0-9][0-9]\)_.*/\1/")
            id="${prefix}-${num}"
            ID_TO_FILE["$id"]="$f"
            ALL_IDS["$id"]=1
            name=$(head -1 "$f" | sed "s/^# *${prefix}-${num}: *//")
            ID_TO_NAME["$id"]="$name"
        done
    done
}

# ─── Reference Storage ─────────────────────────────────────────────
# REFS["type:SOURCE_ID"] = "TARGET1 TARGET2 ..."

declare -A REFS

add_ref() { # <type> <source> <target>
    local key="$1:$2"
    REFS["$key"]="${REFS[$key]:-}${REFS[$key]:+ }$3"
}

has_ref() { # <type> <source> <target> -> exit code
    [[ " ${REFS[$1:$2]:-} " == *" $3 "* ]]
}

# ─── Section Parser ────────────────────────────────────────────────

# Extract text lines within a section (between heading and next same/higher-level heading)
section_lines() { # <file> <heading> <level>
    awk -v section="$2" -v level="$3" '
        BEGIN { found = 0 }
        $0 == section { found = 1; next }
        found && /^#/ { match($0, /^#+/); if (RLENGTH <= level) exit }
        found { print }
    ' "$1"
}

# Extract unique IDs matching a pattern from a section
section_ids() { # <file> <heading> <level> <id_pattern>
    section_lines "$1" "$2" "$3" | grep -oE "$4" | sort -u || true
}

# ─── Parse All Documents ──────────────────────────────────────────

parse_all() {
    local id file x parties
    for id in "${!ALL_IDS[@]}"; do
        file="${ID_TO_FILE[$id]}"
        case "$id" in
            REQ-*)
                for x in $(section_ids "$file" "## Allocated To" 2 "UNIT-[0-9]{3}"); do
                    add_ref req_alloc "$id" "$x"
                done
                for x in $(section_ids "$file" "## Interfaces" 2 "INT-[0-9]{3}"); do
                    add_ref req_iface "$id" "$x"
                done
                ;;
            UNIT-*)
                for x in $(section_ids "$file" "## Implements Requirements" 2 "REQ-[0-9]{3}"); do
                    add_ref unit_impl "$id" "$x"
                done
                for x in $(section_ids "$file" "### Provides" 3 "INT-[0-9]{3}"); do
                    add_ref unit_prov "$id" "$x"
                done
                for x in $(section_ids "$file" "### Consumes" 3 "INT-[0-9]{3}"); do
                    add_ref unit_cons "$id" "$x"
                done
                ;;
            INT-*)
                parties=$(section_lines "$file" "## Parties" 2)
                for x in $(echo "$parties" | grep -i 'Provider' | grep -oE 'UNIT-[0-9]{3}' || true); do
                    add_ref int_prov "$id" "$x"
                done
                for x in $(echo "$parties" | grep -i 'Consumer' | grep -oE 'UNIT-[0-9]{3}' || true); do
                    add_ref int_cons "$id" "$x"
                done
                for x in $(section_ids "$file" "## Referenced By" 2 "REQ-[0-9]{3}"); do
                    add_ref int_refby "$id" "$x"
                done
                ;;
        esac
    done
}

# ─── Insertion Helper ─────────────────────────────────────────────

# Insert a line after the last list item in a section (or after the heading if none)
insert_in_section() { # <file> <heading> <level> <new_line>
    local file="$1" heading="$2" level="$3" new_line="$4"

    # Find the line number to insert after
    local insert_after
    insert_after=$(awk -v section="$heading" -v level="$level" '
        BEGIN { in_sec = 0; last_item = 0; sec_line = 0 }
        $0 == section { in_sec = 1; sec_line = NR; next }
        in_sec && /^#/ { match($0, /^#+/); if (RLENGTH <= level) in_sec = 0 }
        in_sec && /^- / { last_item = NR }
        END {
            if (last_item > 0) print last_item
            else if (sec_line > 0) print sec_line
            else print 0
        }
    ' "$file")

    if [ "$insert_after" -eq 0 ]; then
        return 1
    fi

    # Insert using awk (cross-platform, avoids sed -i differences)
    local temp
    temp=$(mktemp)
    awk -v after="$insert_after" -v newline="$new_line" '
        { print }
        NR == after { print newline }
    ' "$file" > "$temp"
    mv "$temp" "$file"
}

# ─── Check & Fix ──────────────────────────────────────────────────

MISSING=0
BROKEN=0
ORPHANS=0
FIXED=0

check_broken() {
    local key source target seen=""
    for key in "${!REFS[@]}"; do
        source="${key#*:}"
        for target in ${REFS[$key]}; do
            if [ -z "${ALL_IDS[$target]:-}" ]; then
                # Deduplicate: same source->target may appear via different ref types
                local pair="$source->$target"
                [[ "$seen" == *"$pair"* ]] && continue
                seen="$seen $pair"
                echo "BROKEN   $source references $target — no matching file found"
                BROKEN=$((BROKEN + 1))
            fi
        done
    done
}

# Check one direction of a bidirectional relationship.
# For each ref fwd:A->B, verify back:B->A exists.
check_pair() { # <fwd_type> <back_type> <fwd_label> <back_label> <back_heading> <back_level> <format>
    local fwd="$1" back="$2" fwd_label="$3" back_label="$4"
    local back_heading="$5" back_level="$6" fmt="$7"
    local key src tgt tgt_base src_name line

    for key in "${!REFS[@]}"; do
        [[ "$key" == "${fwd}:"* ]] || continue
        src="${key#*:}"
        for tgt in ${REFS[$key]}; do
            # Skip broken references (reported separately)
            [ -z "${ALL_IDS[$tgt]:-}" ] && continue
            # Skip if back-reference already exists
            has_ref "$back" "$tgt" "$src" && continue

            tgt_base=$(basename "${ID_TO_FILE[$tgt]}")
            src_name="${ID_TO_NAME[$src]:-}"

            if $FIX_MODE; then
                case "$fmt" in
                    list)     line="- ${src} (${src_name})" ;;
                    provider) line="- **Provider:** ${src} (${src_name})" ;;
                    consumer) line="- **Consumer:** ${src} (${src_name})" ;;
                esac
                if insert_in_section "${ID_TO_FILE[$tgt]}" "$back_heading" "$back_level" "$line"; then
                    echo "FIXED    ${tgt_base}: added ${src} to \"${back_label}\""
                    FIXED=$((FIXED + 1))
                    add_ref "$back" "$tgt" "$src"
                else
                    echo "SKIPPED  ${tgt_base}: \"${back_label}\" section not found"
                    MISSING=$((MISSING + 1))
                fi
            else
                echo "MISSING  ${tgt_base} \"${back_label}\" lacks ${src}"
                echo "  reason: ${src} \"${fwd_label}\" references ${tgt}"
                MISSING=$((MISSING + 1))
            fi
        done
    done
}

check_consistency() {
    # REQ.AllocatedTo <-> UNIT.ImplementsReq
    check_pair req_alloc unit_impl \
        "Allocated To" "Implements Requirements" \
        "## Implements Requirements" 2 list
    check_pair unit_impl req_alloc \
        "Implements Requirements" "Allocated To" \
        "## Allocated To" 2 list

    # REQ.Interfaces <-> INT.ReferencedBy
    check_pair req_iface int_refby \
        "Interfaces" "Referenced By" \
        "## Referenced By" 2 list
    check_pair int_refby req_iface \
        "Referenced By" "Interfaces" \
        "## Interfaces" 2 list

    # UNIT.Provides <-> INT.Provider
    check_pair unit_prov int_prov \
        "Provides" "Parties (Provider)" \
        "## Parties" 2 provider
    check_pair int_prov unit_prov \
        "Parties (Provider)" "Provides" \
        "### Provides" 3 list

    # UNIT.Consumes <-> INT.Consumer
    check_pair unit_cons int_cons \
        "Consumes" "Parties (Consumer)" \
        "## Parties" 2 consumer
    check_pair int_cons unit_cons \
        "Parties (Consumer)" "Consumes" \
        "### Consumes" 3 list
}

check_orphans() {
    local id found key target
    for id in "${!ALL_IDS[@]}"; do
        found=false
        for key in "${!REFS[@]}"; do
            for target in ${REFS[$key]}; do
                if [ "$target" = "$id" ]; then
                    found=true
                    break 2
                fi
            done
        done
        if ! $found; then
            echo "ORPHAN   ${id} (${ID_TO_NAME[$id]:-}) — not referenced by any document"
            ORPHANS=$((ORPHANS + 1))
        fi
    done
}

# ─── Main ─────────────────────────────────────────────────────────

build_id_map

REQ_N=0 INT_N=0 UNIT_N=0
for id in "${!ALL_IDS[@]}"; do
    case "$id" in
        REQ-*)  REQ_N=$((REQ_N + 1)) ;;
        INT-*)  INT_N=$((INT_N + 1)) ;;
        UNIT-*) UNIT_N=$((UNIT_N + 1)) ;;
    esac
done

echo "# Traceability Sync$($FIX_MODE && echo ' (--fix)')"
echo ""
echo "Scanned: ${REQ_N} requirements, ${INT_N} interfaces, ${UNIT_N} design units"
echo ""

if [ $((REQ_N + INT_N + UNIT_N)) -eq 0 ]; then
    echo "No specification documents found in doc/."
    exit 0
fi

parse_all
check_broken
check_consistency
check_orphans

echo ""
TOTAL=$((MISSING + BROKEN + ORPHANS))

if $FIX_MODE; then
    echo "Summary: ${FIXED} fixed, ${TOTAL} remaining issues"
else
    echo "Summary: ${MISSING} missing, ${BROKEN} broken, ${ORPHANS} orphans"
fi

if [ "$TOTAL" -eq 0 ]; then
    echo "All cross-references are consistent."
fi

exit $((TOTAL > 0 ? 1 : 0))
