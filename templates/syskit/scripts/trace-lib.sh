#!/bin/bash
# Shared functions for trace-sync.sh and trace-query.sh
# Sourced, not executed directly.

# Require bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: bash 4+ required (found ${BASH_VERSION})" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

REQ_DIR="$PROJECT_ROOT/doc/requirements"
INT_DIR="$PROJECT_ROOT/doc/interfaces"
UNIT_DIR="$PROJECT_ROOT/doc/design"
VER_DIR="$PROJECT_ROOT/doc/verification"

# ─── ID Map ────────────────────────────────────────────────────────

declare -A ID_TO_FILE    # ID -> full file path
declare -A ID_TO_NAME    # ID -> human-readable name from H1
declare -A ALL_IDS       # ID -> 1

# Regex patterns for hierarchical IDs: XXX-NNN or XXX-NNN.NN
REQ_PAT='REQ-[0-9]{3}(\.[0-9]{2})?'
INT_PAT='INT-[0-9]{3}(\.[0-9]{2})?'
UNIT_PAT='UNIT-[0-9]{3}(\.[0-9]{2})?'
VER_PAT='VER-[0-9]{3}(\.[0-9]{2})?'

build_id_map() {
    local tag dir prefix entry base num id name
    for entry in "req:$REQ_DIR:REQ" "int:$INT_DIR:INT" "unit:$UNIT_DIR:UNIT" "ver:$VER_DIR:VER"; do
        IFS=':' read -r tag dir prefix <<< "$entry"
        [ -d "$dir" ] || continue
        for f in "$dir"/${tag}_*.md; do
            [ -f "$f" ] || continue
            base=$(basename "$f")
            [[ "$base" == *_000_template* ]] && continue
            if [[ "$base" =~ ^${tag}_([0-9]{3}(\.[0-9]{2})?)_.+\.md$ ]]; then
                num="${BASH_REMATCH[1]}"
                id="${prefix}-${num}"
                ID_TO_FILE["$id"]="$f"
                ALL_IDS["$id"]=1
                name=$(head -1 "$f" | sed "s/^# *${prefix}-${num}: *//")
                ID_TO_NAME["$id"]="$name"
            fi
        done
    done
}

# ─── Section Parser ────────────────────────────────────────────────

section_lines() { # <file> <heading> <level>
    awk -v section="$2" -v level="$3" '
        BEGIN { found = 0 }
        $0 == section { found = 1; next }
        found && /^#/ { match($0, /^#+/); if (RLENGTH <= level) exit }
        found { print }
    ' "$1"
}

section_ids() { # <file> <heading> <level> <id_pattern>
    section_lines "$1" "$2" "$3" | grep -oE "$4" | sort -u || true
}

# ─── Reference Storage ─────────────────────────────────────────────
# REFS["type:SOURCE_ID"] = "TARGET1 TARGET2 ..."

declare -A REFS

add_ref() { # <type> <source> <target>
    local key="$1:$2"
    REFS["$key"]="${REFS[$key]:-}${REFS[$key]:+ }$3"
}

# ─── Parse Forward References ──────────────────────────────────────

parse_forward_refs() {
    local id file x
    for id in "${!ALL_IDS[@]}"; do
        file="${ID_TO_FILE[$id]}"
        case "$id" in
            REQ-*)
                for x in $(section_ids "$file" "## Interfaces" 2 "$INT_PAT"); do
                    add_ref req_iface "$id" "$x"
                done
                ;;
            UNIT-*)
                for x in $(section_ids "$file" "## Implements Requirements" 2 "$REQ_PAT"); do
                    add_ref unit_impl "$id" "$x"
                done
                for x in $(section_ids "$file" "### Provides" 3 "$INT_PAT"); do
                    add_ref unit_prov "$id" "$x"
                done
                for x in $(section_ids "$file" "### Consumes" 3 "$INT_PAT"); do
                    add_ref unit_cons "$id" "$x"
                done
                ;;
            VER-*)
                for x in $(section_ids "$file" "## Verifies Requirements" 2 "$REQ_PAT"); do
                    add_ref ver_req "$id" "$x"
                done
                for x in $(section_ids "$file" "## Verified Design Units" 2 "$UNIT_PAT"); do
                    add_ref ver_unit "$id" "$x"
                done
                ;;
            INT-*)
                # Interfaces reference no other syskit documents
                ;;
        esac
    done
}

# ─── ID Counts ─────────────────────────────────────────────────────

count_ids() {
    REQ_N=0 INT_N=0 UNIT_N=0 VER_N=0
    for id in "${!ALL_IDS[@]}"; do
        case "$id" in
            REQ-*)  REQ_N=$((REQ_N + 1)) ;;
            INT-*)  INT_N=$((INT_N + 1)) ;;
            UNIT-*) UNIT_N=$((UNIT_N + 1)) ;;
            VER-*)  VER_N=$((VER_N + 1)) ;;
        esac
    done
}
