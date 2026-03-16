#!/bin/bash
# Query cross-references: reverse lookups and coverage reports
# Usage: trace-query.sh <ID>             — show what references this ID
#        trace-query.sh --coverage       — full traceability matrix
#        trace-query.sh --unimplemented  — REQs with no UNIT implementing them
#        trace-query.sh --unverified     — REQs with no VER verifying them
#        trace-query.sh --untested      — VERs with method=Test but no Ver-ref in test files
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/trace-lib.sh"

# ─── Reverse Lookup ──────────────────────────────────────────────

query_id() {
    local target="$1"
    if [ -z "${ALL_IDS[$target]:-}" ]; then
        echo "Error: $target not found" >&2
        exit 1
    fi

    echo "# $target: ${ID_TO_NAME[$target]:-}"
    echo ""

    local key source found=false
    case "$target" in
        INT-*)
            echo "## Referenced by Requirements"
            for key in "${!REFS[@]}"; do
                [[ "$key" == req_iface:* ]] || continue
                source="${key#*:}"
                for t in ${REFS[$key]}; do
                    [ "$t" = "$target" ] && echo "- $source (${ID_TO_NAME[$source]:-})" && found=true
                done
            done
            $found || echo "- (none)"

            echo ""
            echo "## Provided by"
            found=false
            for key in "${!REFS[@]}"; do
                [[ "$key" == unit_prov:* ]] || continue
                source="${key#*:}"
                for t in ${REFS[$key]}; do
                    [ "$t" = "$target" ] && echo "- $source (${ID_TO_NAME[$source]:-})" && found=true
                done
            done
            $found || echo "- (none)"

            echo ""
            echo "## Consumed by"
            found=false
            for key in "${!REFS[@]}"; do
                [[ "$key" == unit_cons:* ]] || continue
                source="${key#*:}"
                for t in ${REFS[$key]}; do
                    [ "$t" = "$target" ] && echo "- $source (${ID_TO_NAME[$source]:-})" && found=true
                done
            done
            $found || echo "- (none)"
            ;;

        REQ-*)
            echo "## Implemented by"
            for key in "${!REFS[@]}"; do
                [[ "$key" == unit_impl:* ]] || continue
                source="${key#*:}"
                for t in ${REFS[$key]}; do
                    [ "$t" = "$target" ] && echo "- $source (${ID_TO_NAME[$source]:-})" && found=true
                done
            done
            $found || echo "- (none)"

            echo ""
            echo "## Verified by"
            found=false
            for key in "${!REFS[@]}"; do
                [[ "$key" == ver_req:* ]] || continue
                source="${key#*:}"
                for t in ${REFS[$key]}; do
                    [ "$t" = "$target" ] && echo "- $source (${ID_TO_NAME[$source]:-})" && found=true
                done
            done
            $found || echo "- (none)"
            ;;

        UNIT-*)
            echo "## Verified by"
            for key in "${!REFS[@]}"; do
                [[ "$key" == ver_unit:* ]] || continue
                source="${key#*:}"
                for t in ${REFS[$key]}; do
                    [ "$t" = "$target" ] && echo "- $source (${ID_TO_NAME[$source]:-})" && found=true
                done
            done
            $found || echo "- (none)"
            ;;

        VER-*)
            echo "## Verifies Requirements"
            for key in "${!REFS[@]}"; do
                [[ "$key" == ver_req:$target ]] || continue
                for t in ${REFS[$key]}; do
                    echo "- $t (${ID_TO_NAME[$t]:-})"
                    found=true
                done
            done
            $found || echo "- (none)"

            echo ""
            echo "## Verified Design Units"
            found=false
            for key in "${!REFS[@]}"; do
                [[ "$key" == ver_unit:$target ]] || continue
                for t in ${REFS[$key]}; do
                    echo "- $t (${ID_TO_NAME[$t]:-})"
                    found=true
                done
            done
            $found || echo "- (none)"

            echo ""
            echo "## Test Files (Ver-ref)"
            found=false
            scan_ver_refs
            local base
            base=$(basename "${ID_TO_FILE[$target]}")
            if [ -n "${VER_REF_FILES[$base]:-}" ]; then
                for tf in ${VER_REF_FILES[$base]}; do
                    echo "- \`$tf\`"
                    found=true
                done
            fi
            $found || echo "- (none)"
            ;;
    esac
}

# ─── Coverage Report ─────────────────────────────────────────────

report_coverage() {
    echo "# Traceability Matrix"
    echo ""

    local req_id key source
    for req_id in $(echo "${!ALL_IDS[@]}" | tr ' ' '\n' | grep '^REQ-' | sort); do
        echo "## $req_id: ${ID_TO_NAME[$req_id]:-}"

        echo "  Interfaces:"
        local found=false
        for t in ${REFS[req_iface:$req_id]:-}; do
            echo "    - $t (${ID_TO_NAME[$t]:-})"
            found=true
        done
        $found || echo "    - (none)"

        echo "  Implemented by:"
        found=false
        for key in "${!REFS[@]}"; do
            [[ "$key" == unit_impl:* ]] || continue
            source="${key#*:}"
            for t in ${REFS[$key]}; do
                [ "$t" = "$req_id" ] && echo "    - $source (${ID_TO_NAME[$source]:-})" && found=true
            done
        done
        $found || echo "    - (none)"

        echo "  Verified by:"
        found=false
        for key in "${!REFS[@]}"; do
            [[ "$key" == ver_req:* ]] || continue
            source="${key#*:}"
            for t in ${REFS[$key]}; do
                [ "$t" = "$req_id" ] && echo "    - $source (${ID_TO_NAME[$source]:-})" && found=true
            done
        done
        $found || echo "    - (none)"

        echo ""
    done
}

# ─── Gap Reports ─────────────────────────────────────────────────

report_unimplemented() {
    echo "# Unimplemented Requirements"
    echo ""
    local count=0
    for req_id in $(echo "${!ALL_IDS[@]}" | tr ' ' '\n' | grep '^REQ-' | sort); do
        local found=false
        for key in "${!REFS[@]}"; do
            [[ "$key" == unit_impl:* ]] || continue
            for t in ${REFS[$key]}; do
                [ "$t" = "$req_id" ] && found=true && break 2
            done
        done
        if ! $found; then
            echo "- $req_id (${ID_TO_NAME[$req_id]:-})"
            count=$((count + 1))
        fi
    done
    echo ""
    echo "$count unimplemented requirement(s)"
}

report_unverified() {
    echo "# Unverified Requirements"
    echo ""
    local count=0
    for req_id in $(echo "${!ALL_IDS[@]}" | tr ' ' '\n' | grep '^REQ-' | sort); do
        local found=false
        for key in "${!REFS[@]}"; do
            [[ "$key" == ver_req:* ]] || continue
            for t in ${REFS[$key]}; do
                [ "$t" = "$req_id" ] && found=true && break 2
            done
        done
        if ! $found; then
            echo "- $req_id (${ID_TO_NAME[$req_id]:-})"
            count=$((count + 1))
        fi
    done
    echo ""
    echo "$count unverified requirement(s)"
}

report_untested() {
    echo "# Untested Verifications"
    echo ""
    echo "VER documents with method=Test that have no Ver-ref in any test file."
    echo ""
    scan_ver_refs
    local count=0
    for ver_id in $(echo "${!ALL_IDS[@]}" | tr ' ' '\n' | grep '^VER-' | sort); do
        local file="${ID_TO_FILE[$ver_id]}"
        local method
        method=$(ver_method "$file")
        [ "$method" != "Test" ] && continue
        local base
        base=$(basename "$file")
        if [ -z "${VER_REF_FILES[$base]:-}" ]; then
            echo "- $ver_id (${ID_TO_NAME[$ver_id]:-})"
            count=$((count + 1))
        fi
    done
    echo ""
    echo "$count untested verification(s)"
}

# ─── Main ─────────────────────────────────────────────────────────

if [ $# -eq 0 ]; then
    echo "Usage: trace-query.sh <ID>             — reverse lookup"
    echo "       trace-query.sh --coverage       — full traceability matrix"
    echo "       trace-query.sh --unimplemented  — REQs with no UNIT"
    echo "       trace-query.sh --unverified     — REQs with no VER"
    echo "       trace-query.sh --untested      — VERs with method=Test but no Ver-ref"
    exit 1
fi

build_id_map
parse_forward_refs

case "$1" in
    --coverage)      report_coverage ;;
    --unimplemented) report_unimplemented ;;
    --unverified)    report_unverified ;;
    --untested)      report_untested ;;
    *)               query_id "$1" ;;
esac
