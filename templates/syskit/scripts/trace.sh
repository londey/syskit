#!/bin/bash
# Show traceability tree for a syskit ID
# Usage: trace.sh <ID>
#   ID can be: REQ-001, INT-002, UNIT-003, VER-004, REQ-001.01, etc.
# Output: structured trace data between TRACE_DATA_START/TRACE_DATA_END markers
# Exit codes: 0 = found, 1 = error, 2 = ID not found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

REQ_DIR="$PROJECT_ROOT/doc/requirements"
INT_DIR="$PROJECT_ROOT/doc/interfaces"
UNIT_DIR="$PROJECT_ROOT/doc/design"
VER_DIR="$PROJECT_ROOT/doc/verification"

if [ -z "${1:-}" ]; then
    echo "Usage: trace.sh <ID>" >&2
    echo "  ID: REQ-001, INT-002, UNIT-003, VER-004, REQ-001.01, etc." >&2
    exit 1
fi

INPUT_ID="$1"

# Require bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: bash 4+ required (found ${BASH_VERSION})" >&2
    exit 1
fi

# ─── ID Map ────────────────────────────────────────────────────────

declare -A ID_TO_FILE    # ID -> full file path
declare -A ID_TO_NAME    # ID -> human-readable name from H1

REQ_PAT='REQ-[0-9]{3}(\.[0-9]{2})?'
INT_PAT='INT-[0-9]{3}(\.[0-9]{2})?'
UNIT_PAT='UNIT-[0-9]{3}(\.[0-9]{2})?'
VER_PAT='VER-[0-9]{3}(\.[0-9]{2})?'
ANY_ID_PAT='(REQ|INT|UNIT|VER)-[0-9]{3}(\.[0-9]{2})?'

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

# Extract first meaningful line from a section (for summaries)
section_first_line() { # <file> <heading> <level>
    section_lines "$1" "$2" "$3" | grep -v '^\s*$' | grep -v '^- ' | grep -v '^|' | head -1 | sed 's/^[[:space:]]*//'
}

# ─── Summary Extraction ───────────────────────────────────────────

extract_summary() { # <id> <file>
    local id="$1" file="$2" summary=""
    case "$id" in
        REQ-*)
            summary=$(section_first_line "$file" "## Requirement" 2)
            ;;
        UNIT-*)
            summary=$(section_first_line "$file" "## Purpose" 2)
            ;;
        INT-*)
            summary=$(section_first_line "$file" "## Specification" 2)
            if [ -z "$summary" ]; then
                summary=$(section_first_line "$file" "### Overview" 3)
            fi
            ;;
        VER-*)
            summary=$(section_first_line "$file" "## Preconditions" 2)
            if [ -z "$summary" ]; then
                # Try procedure
                summary=$(section_first_line "$file" "## Procedure" 2)
            fi
            ;;
    esac
    # Trim to reasonable length
    if [ ${#summary} -gt 120 ]; then
        summary="${summary:0:117}..."
    fi
    echo "$summary"
}

# ─── Implementation Files (Spec-ref) ──────────────────────────────

find_impl_files() { # <unit_basename>
    local unit_basename="$1"
    local unit_file="$UNIT_DIR/$unit_basename"
    [ -f "$unit_file" ] || return

    # Get files listed in ## Implementation section
    awk '
        BEGIN { found = 0 }
        $0 == "## Implementation" { found = 1; next }
        found && /^#/ { match($0, /^#+/); if (RLENGTH <= 2) exit }
        found && /^- `[^`]+`/ {
            match($0, /`[^`]+`/)
            path = substr($0, RSTART+1, RLENGTH-2)
            if (path !~ /[<>]/) print path
        }
    ' "$unit_file"
}

# ─── Trace Collection ─────────────────────────────────────────────

# Emit a NODE block
emit_node() { # <id> <depth>
    local id="$1" depth="$2"
    local file="${ID_TO_FILE[$id]:-}"
    local title="${ID_TO_NAME[$id]:-}"
    local relpath summary

    [ -z "$file" ] && return

    relpath="${file#$PROJECT_ROOT/}"
    summary=$(extract_summary "$id" "$file")

    echo "NODE ${depth} ${id}"
    echo "  FILE ${relpath}"
    echo "  TITLE ${title}"
    [ -n "$summary" ] && echo "  SUMMARY ${summary}"
}

# Emit a SECTION with targets
emit_section() { # <section_name> <id_list...>
    local section_name="$1"
    shift
    local ids=("$@")

    [ ${#ids[@]} -eq 0 ] && return

    echo "  SECTION ${section_name}"
    for id in "${ids[@]}"; do
        local file="${ID_TO_FILE[$id]:-}"
        local title="${ID_TO_NAME[$id]:-}"
        if [ -n "$file" ]; then
            local relpath="${file#$PROJECT_ROOT/}"
            echo "    LINK ${id} | ${relpath} | ${title}"
        else
            echo "    LINK ${id} | (not found) | "
        fi
    done
}

# Emit implementation file references for a UNIT
emit_impl() { # <id>
    local id="$1"
    local file="${ID_TO_FILE[$id]:-}"
    [ -z "$file" ] && return

    local base=$(basename "$file")
    local impl_files
    impl_files=$(find_impl_files "$base")
    [ -z "$impl_files" ] && return

    echo "  SECTION Implementation Files"
    while IFS= read -r impl_path; do
        [ -z "$impl_path" ] && continue
        if [ -f "$PROJECT_ROOT/$impl_path" ]; then
            echo "    IMPL ${impl_path}"
        else
            echo "    IMPL ${impl_path} (not found)"
        fi
    done <<< "$impl_files"
}

# Collect trace data for one node
trace_node() { # <id> <depth>
    local id="$1" depth="$2"
    local file="${ID_TO_FILE[$id]:-}"

    [ -z "$file" ] && return

    emit_node "$id" "$depth"

    local ids_arr

    case "$id" in
        REQ-*)
            # Parent requirements
            mapfile -t ids_arr < <(section_ids "$file" "## Parent Requirements" 2 "$REQ_PAT")
            emit_section "Parent Requirements" "${ids_arr[@]}"

            # Allocated To (design units)
            mapfile -t ids_arr < <(section_ids "$file" "## Allocated To" 2 "$UNIT_PAT")
            emit_section "Allocated To" "${ids_arr[@]}"

            # Interfaces
            mapfile -t ids_arr < <(section_ids "$file" "## Interfaces" 2 "$INT_PAT")
            emit_section "Interfaces" "${ids_arr[@]}"

            # Verified By
            mapfile -t ids_arr < <(section_ids "$file" "## Verified By" 2 "$VER_PAT")
            emit_section "Verified By" "${ids_arr[@]}"
            ;;

        UNIT-*)
            # Implements Requirements
            mapfile -t ids_arr < <(section_ids "$file" "## Implements Requirements" 2 "$REQ_PAT")
            emit_section "Implements Requirements" "${ids_arr[@]}"

            # Provides interfaces
            mapfile -t ids_arr < <(section_ids "$file" "### Provides" 3 "$INT_PAT")
            emit_section "Provides" "${ids_arr[@]}"

            # Consumes interfaces
            mapfile -t ids_arr < <(section_ids "$file" "### Consumes" 3 "$INT_PAT")
            emit_section "Consumes" "${ids_arr[@]}"

            # Verification
            mapfile -t ids_arr < <(section_ids "$file" "## Verification" 2 "$VER_PAT")
            emit_section "Verification" "${ids_arr[@]}"

            # Implementation files
            emit_impl "$id"
            ;;

        INT-*)
            # Provider
            local parties
            parties=$(section_lines "$file" "## Parties" 2)
            mapfile -t ids_arr < <(echo "$parties" | grep -i 'Provider' | grep -oE "$UNIT_PAT" || true)
            emit_section "Provider" "${ids_arr[@]}"

            # Consumer
            mapfile -t ids_arr < <(echo "$parties" | grep -i 'Consumer' | grep -oE "$UNIT_PAT" || true)
            emit_section "Consumer" "${ids_arr[@]}"

            # Referenced By
            mapfile -t ids_arr < <(section_ids "$file" "## Referenced By" 2 "$REQ_PAT")
            emit_section "Referenced By" "${ids_arr[@]}"
            ;;

        VER-*)
            # Verifies Requirements
            mapfile -t ids_arr < <(section_ids "$file" "## Verifies Requirements" 2 "$REQ_PAT")
            emit_section "Verifies Requirements" "${ids_arr[@]}"

            # Verified Design Units
            mapfile -t ids_arr < <(section_ids "$file" "## Verified Design Units" 2 "$UNIT_PAT")
            emit_section "Verified Design Units" "${ids_arr[@]}"
            ;;
    esac
}

# ─── Main ─────────────────────────────────────────────────────────

build_id_map

# Resolve input ID (normalize case: accept req-001, Req-001, etc.)
RESOLVED_ID=$(echo "$INPUT_ID" | tr '[:lower:]' '[:upper:]')

if [ -z "${ID_TO_FILE[$RESOLVED_ID]:-}" ]; then
    echo "Error: ID '$INPUT_ID' not found" >&2
    echo "" >&2
    echo "Available IDs:" >&2
    for id in $(echo "${!ID_TO_FILE[@]}" | tr ' ' '\n' | sort); do
        echo "  $id: ${ID_TO_NAME[$id]:-}" >&2
    done
    exit 2
fi

# Collect all IDs referenced by the root node (depth 1 neighbors)
ROOT_FILE="${ID_TO_FILE[$RESOLVED_ID]}"
NEIGHBOR_IDS=()

# Gather all referenced IDs from the root file
while IFS= read -r ref_id; do
    [ -z "$ref_id" ] && continue
    [ "$ref_id" = "$RESOLVED_ID" ] && continue
    NEIGHBOR_IDS+=("$ref_id")
done < <(grep -oE "$ANY_ID_PAT" "$ROOT_FILE" | sort -u)

echo "TRACE_DATA_START"
echo ""

# Emit root node (depth 0)
trace_node "$RESOLVED_ID" 0

echo ""

# Emit neighbor nodes (depth 1)
declare -A SEEN
SEEN["$RESOLVED_ID"]=1

for nid in "${NEIGHBOR_IDS[@]}"; do
    [ -n "${SEEN[$nid]:-}" ] && continue
    [ -z "${ID_TO_FILE[$nid]:-}" ] && continue
    SEEN["$nid"]=1
    trace_node "$nid" 1
    echo ""
done

echo "TRACE_DATA_END"
