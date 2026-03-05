#!/bin/bash
# Validate forward cross-references between spec documents
# Usage: trace-sync.sh
# Exit codes: 0 = all consistent, 1 = issues found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/trace-lib.sh"

# ─── Check & Report ──────────────────────────────────────────────

BROKEN=0
DIRECTION=0
ORPHANS=0

check_broken() {
    local key source target seen=""
    for key in "${!REFS[@]}"; do
        source="${key#*:}"
        for target in ${REFS[$key]}; do
            if [ -z "${ALL_IDS[$target]:-}" ]; then
                local pair="$source->$target"
                [[ "$seen" == *"$pair"* ]] && continue
                seen="$seen $pair"
                echo "BROKEN   $source references $target — no matching file found"
                BROKEN=$((BROKEN + 1))
            fi
        done
    done
}

check_direction() {
    local key source target
    for key in "${!REFS[@]}"; do
        source="${key#*:}"
        for target in ${REFS[$key]}; do
            [ -z "${ALL_IDS[$target]:-}" ] && continue
            case "$source" in
                REQ-*)
                    case "$target" in
                        INT-*) ;;
                        *) echo "DIRECTION  $source references $target — requirements may only reference interfaces"
                           DIRECTION=$((DIRECTION + 1)) ;;
                    esac
                    ;;
                UNIT-*)
                    case "$target" in
                        REQ-*|INT-*) ;;
                        *) echo "DIRECTION  $source references $target — design units may only reference requirements and interfaces"
                           DIRECTION=$((DIRECTION + 1)) ;;
                    esac
                    ;;
                VER-*)
                    case "$target" in
                        REQ-*|UNIT-*|INT-*) ;;
                        *) echo "DIRECTION  $source references $target — verifications may only reference requirements, units, and interfaces"
                           DIRECTION=$((DIRECTION + 1)) ;;
                    esac
                    ;;
                INT-*)
                    echo "DIRECTION  $source references $target — interfaces must not reference other documents"
                    DIRECTION=$((DIRECTION + 1))
                    ;;
            esac
        done
    done
}

check_orphans() {
    local id found key target
    for id in "${!ALL_IDS[@]}"; do
        # VER documents are at the top of the hierarchy — they cannot be orphans
        [[ "$id" == VER-* ]] && continue

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
count_ids

echo "# Traceability Check"
echo ""
echo "Scanned: ${REQ_N} requirements, ${INT_N} interfaces, ${UNIT_N} design units, ${VER_N} verifications"
echo ""

if [ $((REQ_N + INT_N + UNIT_N + VER_N)) -eq 0 ]; then
    echo "No specification documents found in doc/."
    exit 0
fi

parse_forward_refs
check_broken
check_direction
check_orphans

echo ""
TOTAL=$((BROKEN + DIRECTION + ORPHANS))

echo "Summary: ${BROKEN} broken, ${DIRECTION} direction violations, ${ORPHANS} orphans"

if [ "$TOTAL" -eq 0 ]; then
    echo "All cross-references are consistent."
fi

exit $((TOTAL > 0 ? 1 : 0))
