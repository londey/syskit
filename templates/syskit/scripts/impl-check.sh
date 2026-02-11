#!/bin/bash
# Check implementation freshness via Spec-ref comment hashes
# Usage: impl-check.sh [UNIT-NNN | unit_NNN_name.md]
#   No argument: full scan, generates .syskit/impl-status.md
#   With argument: filter to one unit, stdout only
# Exit codes: 0 = all current, 1 = stale or issues found
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

# ─── Cross-platform hash command ─────────────────────────────────

if command -v sha256sum &> /dev/null; then
    hash_cmd() { sha256sum "$1" | cut -c1-16; }
else
    hash_cmd() { shasum -a 256 "$1" | cut -c1-16; }
fi

# ─── Resolve UNIT filter ─────────────────────────────────────────

FILTER_BASENAME=""

if [ -n "$FILTER" ]; then
    # Try direct basename match
    if [ -f "$UNIT_DIR/$FILTER" ]; then
        FILTER_BASENAME="$FILTER"
    else
        # Extract 3-digit number from UNIT-NNN, unit-NNN, etc.
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

# source_file -> unit_basename:hash:date (one entry per Spec-ref line)
declare -A SPEC_REFS        # "src_file|unit_basename" -> "hash date"
declare -a REF_KEYS=()      # ordered list of "src_file|unit_basename" keys

scan_spec_refs() {
    local files
    files=$(git ls-files --cached --others --exclude-standard 2>/dev/null | xargs grep -lI "Spec-ref:" 2>/dev/null || true)

    [ -z "$files" ] && return

    local src_file line unit_basename ref_hash ref_date
    for src_file in $files; do
        while IFS= read -r line; do
            # Extract unit filename
            unit_basename=$(echo "$line" | sed -n 's/.*Spec-ref:[[:space:]]*\([^ ]*\.md\).*/\1/p')
            [ -z "$unit_basename" ] && continue

            # Apply filter
            if [ -n "$FILTER_BASENAME" ] && [ "$unit_basename" != "$FILTER_BASENAME" ]; then
                continue
            fi

            # Extract hash (16 hex chars between backticks)
            ref_hash=$(echo "$line" | sed -n 's/.*`\([0-9a-f]\{16\}\)`.*/\1/p')
            [ -z "$ref_hash" ] && continue

            # Extract date
            ref_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | tail -1)
            [ -z "$ref_date" ] && ref_date="unknown"

            local key="${src_file}|${unit_basename}"
            SPEC_REFS["$key"]="$ref_hash $ref_date"
            REF_KEYS+=("$key")
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

        # Apply filter
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

        [ -n "$impl_files" ] && UNIT_IMPL_FILES["$base"]="$impl_files"
    done
}

# ─── Compare hashes ──────────────────────────────────────────────

CURRENT_COUNT=0
STALE_COUNT=0
MISSING_COUNT=0

declare -a RESULT_LINES=()  # "status|src_file|unit_basename|ref_hash|current_hash|ref_date"

compare_hashes() {
    local key src_file unit_basename ref_hash ref_date current_hash unit_path status
    for key in "${REF_KEYS[@]}"; do
        src_file="${key%%|*}"
        unit_basename="${key##*|}"
        ref_hash=$(echo "${SPEC_REFS[$key]}" | cut -d' ' -f1)
        ref_date=$(echo "${SPEC_REFS[$key]}" | cut -d' ' -f2)

        unit_path="$UNIT_DIR/$unit_basename"
        if [ ! -f "$unit_path" ]; then
            status="missing"
            current_hash="n/a"
            MISSING_COUNT=$((MISSING_COUNT + 1))
        else
            current_hash=$(hash_cmd "$unit_path")
            if [ "$ref_hash" = "$current_hash" ]; then
                status="current"
                CURRENT_COUNT=$((CURRENT_COUNT + 1))
            else
                status="stale"
                STALE_COUNT=$((STALE_COUNT + 1))
            fi
        fi

        RESULT_LINES+=("${status}|${src_file}|${unit_basename}|${ref_hash}|${current_hash}|${ref_date}")
    done
}

# ─── Find untracked units ────────────────────────────────────────

UNTRACKED_COUNT=0

declare -a UNTRACKED_LINES=()  # "unit_basename|impl_files"

find_untracked() {
    local unit_basename impl_list has_any_ref impl_path key
    for unit_basename in "${!UNIT_IMPL_FILES[@]}"; do
        impl_list="${UNIT_IMPL_FILES[$unit_basename]}"
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
            # Collapse newlines to comma-separated for display
            local display_files
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
        echo "- Current: $CURRENT_COUNT"
        echo "- Stale: $STALE_COUNT"
        echo "- Missing unit: $MISSING_COUNT"
        echo "- Untracked units: $UNTRACKED_COUNT"
        echo ""

        if [ ${#RESULT_LINES[@]} -gt 0 ]; then
            echo "## Spec-ref Status"
            echo ""
            echo "| Source File | Unit | Ref Hash | Current Hash | Status | Sync Date |"
            echo "|------------|------|----------|--------------|--------|-----------|"

            local entry status src_file unit_basename ref_hash current_hash ref_date
            for entry in "${RESULT_LINES[@]}"; do
                IFS='|' read -r status src_file unit_basename ref_hash current_hash ref_date <<< "$entry"
                # Derive UNIT-NNN from basename
                local unit_num
                unit_num=$(echo "$unit_basename" | sed -n 's/unit_\([0-9][0-9][0-9]\)_.*/\1/p')
                local unit_id="UNIT-${unit_num}"
                echo "| \`$src_file\` | $unit_id | \`$ref_hash\` | \`$current_hash\` | $status | $ref_date |"
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
        IFS='|' read -r status src_file unit_basename _ _ _ <<< "$entry"
        case "$status" in
            current) echo "✓ current — $src_file" ;;
            stale)   echo "⚠ stale   — $src_file" ;;
            missing) echo "✗ missing — $src_file (references $unit_basename)" ;;
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
compare_hashes
find_untracked

if [ -z "$FILTER" ]; then
    generate_report
    echo ""
    print_summary
else
    generate_report
fi

echo ""
TOTAL=$((STALE_COUNT + MISSING_COUNT + UNTRACKED_COUNT))

if [ "$TOTAL" -eq 0 ] && [ $((CURRENT_COUNT + UNTRACKED_COUNT)) -eq 0 ]; then
    echo "No Spec-ref lines found."
elif [ "$TOTAL" -eq 0 ]; then
    echo "All implementations are current."
else
    echo "Summary: $CURRENT_COUNT current, $STALE_COUNT stale, $MISSING_COUNT missing, $UNTRACKED_COUNT untracked"
fi

exit $((TOTAL > 0 ? 1 : 0))
