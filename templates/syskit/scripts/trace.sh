#!/bin/bash
# Show traceability tree for a syskit ID
# Usage: trace.sh <ID>
#   ID can be: REQ-001, INT-002, UNIT-003, VER-004, REQ-001.01, etc.
# Output: structured trace data between TRACE_DATA_START/TRACE_DATA_END markers
# Exit codes: 0 = found, 1 = error, 2 = ID not found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/trace-lib.sh"

ANY_ID_PAT='(REQ|INT|UNIT|VER)-[0-9]{3}(\.[0-9]{2})?'

if [ -z "${1:-}" ]; then
    echo "Usage: trace.sh <ID>" >&2
    echo "  ID: REQ-001, INT-002, UNIT-003, VER-004, REQ-001.01, etc." >&2
    exit 1
fi

INPUT_ID="$1"

# ─── Summary Extraction ───────────────────────────────────────────

# Extract first meaningful line from a section (for summaries)
section_first_line() { # <file> <heading> <level>
    section_lines "$1" "$2" "$3" | grep -v '^\s*$' | grep -v '^- ' | grep -v '^|' | head -1 | sed 's/^[[:space:]]*//'
}

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
                summary=$(section_first_line "$file" "## Procedure" 2)
            fi
            ;;
    esac
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

# ─── Reverse Lookup Helpers ──────────────────────────────────────

# Find all source IDs that reference a target via a specific ref type
reverse_lookup() { # <ref_type> <target_id>
    local ref_type="$1" target_id="$2"
    local key source
    for key in "${!REFS[@]}"; do
        [[ "$key" == "${ref_type}:"* ]] || continue
        source="${key#*:}"
        for t in ${REFS[$key]}; do
            [ "$t" = "$target_id" ] && echo "$source"
        done
    done | sort -u
}

# ─── Trace Collection ─────────────────────────────────────────────

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

trace_node() { # <id> <depth>
    local id="$1" depth="$2"
    local file="${ID_TO_FILE[$id]:-}"

    [ -z "$file" ] && return

    emit_node "$id" "$depth"

    local ids_arr

    case "$id" in
        REQ-*)
            # Forward: Parent Requirements
            mapfile -t ids_arr < <(section_ids "$file" "## Parent Requirements" 2 "$REQ_PAT")
            emit_section "Parent Requirements" "${ids_arr[@]}"

            # Forward: Interfaces
            mapfile -t ids_arr < <(section_ids "$file" "## Interfaces" 2 "$INT_PAT")
            emit_section "Interfaces" "${ids_arr[@]}"

            # Reverse: Implemented by (UNITs that reference this REQ)
            mapfile -t ids_arr < <(reverse_lookup unit_impl "$id")
            emit_section "Implemented By" "${ids_arr[@]}"

            # Reverse: Verified by (VERs that reference this REQ)
            mapfile -t ids_arr < <(reverse_lookup ver_req "$id")
            emit_section "Verified By" "${ids_arr[@]}"
            ;;

        UNIT-*)
            # Forward: Implements Requirements
            mapfile -t ids_arr < <(section_ids "$file" "## Implements Requirements" 2 "$REQ_PAT")
            emit_section "Implements Requirements" "${ids_arr[@]}"

            # Forward: Provides interfaces
            mapfile -t ids_arr < <(section_ids "$file" "### Provides" 3 "$INT_PAT")
            emit_section "Provides" "${ids_arr[@]}"

            # Forward: Consumes interfaces
            mapfile -t ids_arr < <(section_ids "$file" "### Consumes" 3 "$INT_PAT")
            emit_section "Consumes" "${ids_arr[@]}"

            # Reverse: Verified by (VERs that reference this UNIT)
            mapfile -t ids_arr < <(reverse_lookup ver_unit "$id")
            emit_section "Verified By" "${ids_arr[@]}"

            # Implementation files
            emit_impl "$id"
            ;;

        INT-*)
            # Reverse: Referenced by (REQs that reference this INT)
            mapfile -t ids_arr < <(reverse_lookup req_iface "$id")
            emit_section "Referenced By" "${ids_arr[@]}"

            # Reverse: Provider (UNITs that provide this INT)
            mapfile -t ids_arr < <(reverse_lookup unit_prov "$id")
            emit_section "Provider" "${ids_arr[@]}"

            # Reverse: Consumer (UNITs that consume this INT)
            mapfile -t ids_arr < <(reverse_lookup unit_cons "$id")
            emit_section "Consumer" "${ids_arr[@]}"
            ;;

        VER-*)
            # Forward: Verifies Requirements
            mapfile -t ids_arr < <(section_ids "$file" "## Verifies Requirements" 2 "$REQ_PAT")
            emit_section "Verifies Requirements" "${ids_arr[@]}"

            # Forward: Verified Design Units
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

# Parse all forward references (needed for reverse lookups)
parse_forward_refs

# Collect all IDs that relate to the root node (forward + reverse)
ROOT_FILE="${ID_TO_FILE[$RESOLVED_ID]}"
declare -A NEIGHBOR_SET

# Forward references from root file
while IFS= read -r ref_id; do
    [ -z "$ref_id" ] && continue
    [ "$ref_id" = "$RESOLVED_ID" ] && continue
    NEIGHBOR_SET["$ref_id"]=1
done < <(grep -oE "$ANY_ID_PAT" "$ROOT_FILE" | sort -u)

# Reverse references to root (scan all forward refs for this target)
for key in "${!REFS[@]}"; do
    local_source="${key#*:}"
    for t in ${REFS[$key]}; do
        if [ "$t" = "$RESOLVED_ID" ] && [ "$local_source" != "$RESOLVED_ID" ]; then
            NEIGHBOR_SET["$local_source"]=1
        fi
    done
done

echo "TRACE_DATA_START"
echo ""

# Emit root node (depth 0)
trace_node "$RESOLVED_ID" 0

echo ""

# Emit neighbor nodes (depth 1)
declare -A SEEN
SEEN["$RESOLVED_ID"]=1

for nid in $(echo "${!NEIGHBOR_SET[@]}" | tr ' ' '\n' | sort); do
    [ -n "${SEEN[$nid]:-}" ] && continue
    [ -z "${ID_TO_FILE[$nid]:-}" ] && continue
    SEEN["$nid"]=1
    trace_node "$nid" 1
    echo ""
done

echo "TRACE_DATA_END"
