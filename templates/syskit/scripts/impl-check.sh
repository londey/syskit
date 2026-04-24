#!/bin/bash
# Check Spec-ref consistency between source files and unit ## Implementation sections
# Usage: impl-check.sh [UNIT-NNN | unit_NNN_name.md]
#   No argument: full scan, generates .syskit/impl-status.md
#   With argument: filter to one unit, stdout only
# Exit codes: 0 = no issues, 1 = missing/orphan/untracked issues found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UNIT_DIR="$PROJECT_ROOT/doc/design"
REPORT="$PROJECT_ROOT/.syskit/impl-status.md"
FILTER="${1:-}"

cd "$PROJECT_ROOT"

# Require bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: bash 4+ required (found ${BASH_VERSION})" >&2
    exit 1
fi

# ─── Resolve UNIT filter ─────────────────────────────────────────

FILTER_BASENAME=""

if [ -n "$FILTER" ]; then
    if [ -f "$UNIT_DIR/$FILTER" ]; then
        FILTER_BASENAME="$FILTER"
    else
        num=$(echo "$FILTER" | grep -oE '[0-9]{3}' | head -1)
        if [ -z "$num" ]; then
            echo "Error: cannot parse unit number from '$FILTER'" >&2
            exit 1
        fi
        matches=("$UNIT_DIR"/unit_${num}_*.md)
        if [ -f "${matches[0]}" ]; then
            FILTER_BASENAME=$(basename "${matches[0]}")
        else
            echo "Error: no unit file found for '$FILTER'" >&2
            exit 1
        fi
    fi
fi

# ─── Scan for Spec-ref lines ─────────────────────────────────────

declare -A SPEC_REFS        # "src_file|unit_basename" -> 1 (presence marker)
declare -a REF_KEYS=()      # ordered list of "src_file|unit_basename" keys

scan_spec_refs() {
    local files
    files=$(git ls-files --cached --others --exclude-standard 2>/dev/null | grep -v '^\.syskit/' | xargs grep -lI "Spec-ref:" 2>/dev/null || true)

    [ -z "$files" ] && return

    local src_file line unit_basename
    for src_file in $files; do
        while IFS= read -r line; do
            unit_basename=$(echo "$line" | sed -n 's/.*Spec-ref:[[:space:]]*\([^ `]*\.md\).*/\1/p')
            [ -z "$unit_basename" ] && continue

            if [ -n "$FILTER_BASENAME" ] && [ "$unit_basename" != "$FILTER_BASENAME" ]; then
                continue
            fi

            local key="${src_file}|${unit_basename}"
            if [ -z "${SPEC_REFS[$key]:-}" ]; then
                SPEC_REFS["$key"]=1
                REF_KEYS+=("$key")
            fi
        done < <(grep "Spec-ref:" "$src_file")
    done
}

# ─── Parse Implementation sections from unit files ────────────────

declare -A UNIT_IMPL_FILES  # unit_basename -> newline-separated list of file paths

parse_impl_sections() {
    local f base impl_files
    for f in "$UNIT_DIR"/unit_[0-9][0-9][0-9]_*.md; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        [[ "$base" == *_000_template* ]] && continue

        if [ -n "$FILTER_BASENAME" ] && [ "$base" != "$FILTER_BASENAME" ]; then
            continue
        fi

        impl_files=$(awk '
            BEGIN { found = 0 }
            $0 == "## Implementation" { found = 1; next }
            found && /^#/ { match($0, /^#+/); if (RLENGTH <= 2) exit }
            found && /^- `[^`]+`/ {
                match($0, /`[^`]+`/)
                path = substr($0, RSTART+1, RLENGTH-2)
                if (path !~ /[<>]/) print path
            }
        ' "$f")

        UNIT_IMPL_FILES["$base"]="$impl_files"
    done
}

# ─── Classify refs: missing unit vs. orphan vs. ok ────────────────

MISSING_COUNT=0
ORPHAN_COUNT=0

declare -a RESULT_LINES=()  # "status|src_file|unit_basename"

classify_refs() {
    local key src_file unit_basename unit_path impl_list listed status
    for key in "${REF_KEYS[@]}"; do
        src_file="${key%%|*}"
        unit_basename="${key##*|}"
        unit_path="$UNIT_DIR/$unit_basename"

        if [ ! -f "$unit_path" ]; then
            status="missing"
            MISSING_COUNT=$((MISSING_COUNT + 1))
        else
            impl_list="${UNIT_IMPL_FILES[$unit_basename]:-}"
            listed=false
            while IFS= read -r impl_path; do
                [ -z "$impl_path" ] && continue
                if [ "$impl_path" = "$src_file" ]; then
                    listed=true
                    break
                fi
            done <<< "$impl_list"

            if $listed; then
                continue
            else
                status="orphan"
                ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
            fi
        fi

        RESULT_LINES+=("${status}|${src_file}|${unit_basename}")
    done
}

# ─── Find untracked units ────────────────────────────────────────

UNTRACKED_COUNT=0

declare -a UNTRACKED_LINES=()  # "unit_basename|impl_files"

find_untracked() {
    local unit_basename impl_list has_any_ref impl_path key display_files
    for unit_basename in "${!UNIT_IMPL_FILES[@]}"; do
        impl_list="${UNIT_IMPL_FILES[$unit_basename]}"
        [ -z "$impl_list" ] && continue

        has_any_ref=false
        while IFS= read -r impl_path; do
            [ -z "$impl_path" ] && continue
            key="${impl_path}|${unit_basename}"
            if [ -n "${SPEC_REFS[$key]:-}" ]; then
                has_any_ref=true
                break
            fi
        done <<< "$impl_list"

        if ! $has_any_ref; then
            display_files=$(echo "$impl_list" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            UNTRACKED_LINES+=("${unit_basename}|${display_files}")
            UNTRACKED_COUNT=$((UNTRACKED_COUNT + 1))
        fi
    done
}

# ─── Report generation ───────────────────────────────────────────

generate_report() {
    local out="/dev/stdout"
    if [ -z "$FILTER" ]; then
        out="$REPORT"
    fi

    {
        echo "# Implementation Status"
        echo ""
        echo "Generated: $(date -Iseconds 2>/dev/null || date)"
        echo ""
        echo "## Summary"
        echo ""
        echo "- Missing unit: $MISSING_COUNT"
        echo "- Orphan refs: $ORPHAN_COUNT"
        echo "- Untracked units: $UNTRACKED_COUNT"
        echo ""

        if [ ${#RESULT_LINES[@]} -gt 0 ]; then
            echo "## Spec-ref Issues"
            echo ""
            echo "| Source File | Unit | Status |"
            echo "|-------------|------|--------|"

            local entry status src_file unit_basename unit_num unit_id
            for entry in "${RESULT_LINES[@]}"; do
                IFS='|' read -r status src_file unit_basename <<< "$entry"
                unit_num=$(echo "$unit_basename" | sed -n 's/unit_\([0-9][0-9][0-9]\)_.*/\1/p')
                unit_id="UNIT-${unit_num}"
                echo "| \`$src_file\` | $unit_id | $status |"
            done
            echo ""
        fi

        if [ ${#UNTRACKED_LINES[@]} -gt 0 ]; then
            echo "## Untracked Units"
            echo ""
            echo "| Unit | Listed Implementation Files |"
            echo "|------|-----------------------------|"

            local entry unit_basename impl_files unit_num unit_id
            for entry in "${UNTRACKED_LINES[@]}"; do
                unit_basename="${entry%%|*}"
                impl_files="${entry##*|}"
                unit_num=$(echo "$unit_basename" | sed -n 's/unit_\([0-9][0-9][0-9]\)_.*/\1/p')
                unit_id="UNIT-${unit_num}"
                echo "| $unit_id | \`$impl_files\` |"
            done
            echo ""
        fi
    } > "$out"

    if [ -z "$FILTER" ]; then
        echo "Report written: $REPORT"
    fi
}

# ─── Stdout summary ──────────────────────────────────────────────

print_summary() {
    local entry status src_file unit_basename

    for entry in "${RESULT_LINES[@]}"; do
        IFS='|' read -r status src_file unit_basename <<< "$entry"
        case "$status" in
            missing) echo "✗ missing — $src_file (references $unit_basename)" ;;
            orphan)  echo "⚠ orphan  — $src_file (Spec-ref to $unit_basename, not in ## Implementation)" ;;
        esac
    done

    for entry in "${UNTRACKED_LINES[@]}"; do
        unit_basename="${entry%%|*}"
        echo "○ untracked — $unit_basename"
    done
}

# ─── Main ─────────────────────────────────────────────────────────

scan_spec_refs
parse_impl_sections
classify_refs
find_untracked

if [ -z "$FILTER" ]; then
    generate_report
    echo ""
    print_summary
else
    generate_report
fi

echo ""
TOTAL=$((MISSING_COUNT + ORPHAN_COUNT + UNTRACKED_COUNT))
TOTAL_REFS=${#REF_KEYS[@]}

if [ "$TOTAL" -eq 0 ] && [ "$TOTAL_REFS" -eq 0 ] && [ "$UNTRACKED_COUNT" -eq 0 ]; then
    echo "No Spec-ref lines found."
elif [ "$TOTAL" -eq 0 ]; then
    echo "All Spec-refs consistent."
else
    echo "Summary: $MISSING_COUNT missing, $ORPHAN_COUNT orphan, $UNTRACKED_COUNT untracked"
fi

exit $((TOTAL > 0 ? 1 : 0))
