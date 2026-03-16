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

# ─── Ver-ref Validation ───────────────────────────────────────────

VER_REF_ISSUES=0

check_ver_refs() {
    # Check 1: Ver-ref targets exist (exclude .syskit/ reference docs which contain examples)
    local files
    files=$(git ls-files --cached --others --exclude-standard 2>/dev/null | grep -v '^\.syskit/' | xargs grep -lI "Ver-ref:" 2>/dev/null || true)

    if [ -n "$files" ]; then
        local src_file line ver_basename
        for src_file in $files; do
            while IFS= read -r line; do
                ver_basename=$(echo "$line" | sed -n 's/.*Ver-ref:[[:space:]]*\([^ ]*\.md\).*/\1/p')
                [ -z "$ver_basename" ] && continue
                if [ ! -f "$VER_DIR/$ver_basename" ]; then
                    echo "BROKEN   $src_file Ver-ref to $ver_basename — file not found"
                    VER_REF_ISSUES=$((VER_REF_ISSUES + 1))
                fi
            done < <(grep "Ver-ref:" "$src_file")
        done
    fi

    # Check 2: Test files listed in ## Test Implementation exist
    for f in "$VER_DIR"/ver_[0-9]*.md; do
        [ -f "$f" ] || continue
        local base
        base=$(basename "$f")
        [[ "$base" == *_000_template* ]] && continue
        local test_files
        test_files=$(awk '
            BEGIN { found = 0 }
            $0 == "## Test Implementation" { found = 1; next }
            found && /^#/ { match($0, /^#+/); if (RLENGTH <= 2) exit }
            found && /^- `[^`]+`/ {
                match($0, /`[^`]+`/)
                path = substr($0, RSTART+1, RLENGTH-2)
                if (path !~ /[<>]/) print path
            }
        ' "$f")
        while IFS= read -r tpath; do
            [ -z "$tpath" ] && continue
            if [ ! -f "$PROJECT_ROOT/$tpath" ]; then
                echo "BROKEN   $base lists test file $tpath in ## Test Implementation — file not found"
                VER_REF_ISSUES=$((VER_REF_ISSUES + 1))
            fi
        done <<< "$test_files"
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
check_ver_refs

echo ""
TOTAL=$((BROKEN + DIRECTION + ORPHANS + VER_REF_ISSUES))

echo "Summary: ${BROKEN} broken, ${DIRECTION} direction violations, ${ORPHANS} orphans, ${VER_REF_ISSUES} ver-ref issues"

if [ "$TOTAL" -eq 0 ]; then
    echo "All cross-references are consistent."
fi

exit $((TOTAL > 0 ? 1 : 0))
