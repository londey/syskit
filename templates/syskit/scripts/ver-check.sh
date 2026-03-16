#!/bin/bash
# Check verification test freshness via Ver-ref comment hashes
# Usage: ver-check.sh [VER-NNN | ver_NNN_name.md]
#   No argument: full scan, generates .syskit/ver-status.md
#   With argument: filter to one VER, stdout only
# Exit codes: 0 = all current, 1 = stale or issues found
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VER_DIR="$PROJECT_ROOT/doc/verification"
REPORT="$PROJECT_ROOT/.syskit/ver-status.md"
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

# ─── Resolve VER filter ──────────────────────────────────────────

FILTER_BASENAME=""

if [ -n "$FILTER" ]; then
    # Try direct basename match
    if [ -f "$VER_DIR/$FILTER" ]; then
        FILTER_BASENAME="$FILTER"
    else
        # Check for hierarchical ID (VER-NNN.NN)
        if echo "$FILTER" | grep -qE '[0-9]{3}\.[0-9]{2}'; then
            num=$(echo "$FILTER" | grep -oE '[0-9]{3}\.[0-9]{2}' | head -1)
            matches=("$VER_DIR"/ver_${num}_*.md)
        else
            # Extract 3-digit number from VER-NNN, ver-NNN, etc.
            num=$(echo "$FILTER" | grep -oE '[0-9]{3}' | head -1)
            if [ -z "$num" ]; then
                echo "Error: cannot parse VER number from '$FILTER'" >&2
                exit 1
            fi
            matches=("$VER_DIR"/ver_${num}_*.md)
        fi
        if [ -f "${matches[0]}" ]; then
            FILTER_BASENAME=$(basename "${matches[0]}")
        else
            echo "Error: no verification file found for '$FILTER'" >&2
            exit 1
        fi
    fi
fi

# ─── Scan for Ver-ref lines ──────────────────────────────────────

# source_file -> ver_basename:hash:date (one entry per Ver-ref line)
declare -A VER_REFS        # "src_file|ver_basename" -> "hash date"
declare -a REF_KEYS=()     # ordered list of "src_file|ver_basename" keys

scan_ver_refs() {
    local files
    files=$(git ls-files --cached --others --exclude-standard 2>/dev/null | grep -v '^\.syskit/' | xargs grep -lI "Ver-ref:" 2>/dev/null || true)

    [ -z "$files" ] && return

    local src_file line ver_basename ref_hash ref_date
    for src_file in $files; do
        while IFS= read -r line; do
            # Extract VER filename
            ver_basename=$(echo "$line" | sed -n 's/.*Ver-ref:[[:space:]]*\([^ ]*\.md\).*/\1/p')
            [ -z "$ver_basename" ] && continue

            # Apply filter
            if [ -n "$FILTER_BASENAME" ] && [ "$ver_basename" != "$FILTER_BASENAME" ]; then
                continue
            fi

            # Extract hash (16 hex chars between backticks)
            ref_hash=$(echo "$line" | sed -n 's/.*`\([0-9a-f]\{16\}\)`.*/\1/p')
            [ -z "$ref_hash" ] && continue

            # Extract date
            ref_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | tail -1)
            [ -z "$ref_date" ] && ref_date="unknown"

            local key="${src_file}|${ver_basename}"
            VER_REFS["$key"]="$ref_hash $ref_date"
            REF_KEYS+=("$key")
        done < <(grep "Ver-ref:" "$src_file")
    done
}

# ─── Parse Test Implementation sections from VER files ────────────

declare -A VER_TEST_FILES  # ver_basename -> newline-separated list of file paths

parse_test_sections() {
    local f base test_files
    for f in "$VER_DIR"/ver_[0-9]*.md; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        [[ "$base" == *_000_template* ]] && continue

        # Apply filter
        if [ -n "$FILTER_BASENAME" ] && [ "$base" != "$FILTER_BASENAME" ]; then
            continue
        fi

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

        [ -n "$test_files" ] && VER_TEST_FILES["$base"]="$test_files"
    done
}

# ─── Compare hashes ──────────────────────────────────────────────

CURRENT_COUNT=0
STALE_COUNT=0
MISSING_COUNT=0

declare -a RESULT_LINES=()  # "status|src_file|ver_basename|ref_hash|current_hash|ref_date"

compare_hashes() {
    local key src_file ver_basename ref_hash ref_date current_hash ver_path status
    for key in "${REF_KEYS[@]}"; do
        src_file="${key%%|*}"
        ver_basename="${key##*|}"
        ref_hash=$(echo "${VER_REFS[$key]}" | cut -d' ' -f1)
        ref_date=$(echo "${VER_REFS[$key]}" | cut -d' ' -f2)

        ver_path="$VER_DIR/$ver_basename"
        if [ ! -f "$ver_path" ]; then
            status="missing"
            current_hash="n/a"
            MISSING_COUNT=$((MISSING_COUNT + 1))
        else
            current_hash=$(hash_cmd "$ver_path")
            if [ "$ref_hash" = "$current_hash" ]; then
                status="current"
                CURRENT_COUNT=$((CURRENT_COUNT + 1))
            else
                status="stale"
                STALE_COUNT=$((STALE_COUNT + 1))
            fi
        fi

        RESULT_LINES+=("${status}|${src_file}|${ver_basename}|${ref_hash}|${current_hash}|${ref_date}")
    done
}

# ─── Find untracked VERs ─────────────────────────────────────────

UNTRACKED_COUNT=0

declare -a UNTRACKED_LINES=()  # "ver_basename|test_files"

find_untracked() {
    local ver_basename test_list has_any_ref test_path key
    for ver_basename in "${!VER_TEST_FILES[@]}"; do
        test_list="${VER_TEST_FILES[$ver_basename]}"
        has_any_ref=false

        while IFS= read -r test_path; do
            [ -z "$test_path" ] && continue
            key="${test_path}|${ver_basename}"
            if [ -n "${VER_REFS[$key]:-}" ]; then
                has_any_ref=true
                break
            fi
        done <<< "$test_list"

        if ! $has_any_ref; then
            # Collapse newlines to comma-separated for display
            local display_files
            display_files=$(echo "$test_list" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            UNTRACKED_LINES+=("${ver_basename}|${display_files}")
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
        echo "# Verification Test Status"
        echo ""
        echo "Generated: $(date -Iseconds 2>/dev/null || date)"
        echo ""
        echo "## Summary"
        echo ""
        echo "- Current: $CURRENT_COUNT"
        echo "- Stale: $STALE_COUNT"
        echo "- Missing VER: $MISSING_COUNT"
        echo "- Untracked VERs: $UNTRACKED_COUNT"
        echo ""

        if [ ${#RESULT_LINES[@]} -gt 0 ]; then
            echo "## Ver-ref Status"
            echo ""
            echo "| Test File | VER | Ref Hash | Current Hash | Status | Sync Date |"
            echo "|-----------|-----|----------|--------------|--------|-----------|"

            local entry status src_file ver_basename ref_hash current_hash ref_date
            for entry in "${RESULT_LINES[@]}"; do
                IFS='|' read -r status src_file ver_basename ref_hash current_hash ref_date <<< "$entry"
                # Derive VER-NNN or VER-NNN.NN from basename
                local ver_num
                ver_num=$(echo "$ver_basename" | sed -n 's/ver_\([0-9][0-9][0-9]\(\.[0-9][0-9]\)\?\)_.*/\1/p')
                local ver_id="VER-${ver_num}"
                echo "| \`$src_file\` | $ver_id | \`$ref_hash\` | \`$current_hash\` | $status | $ref_date |"
            done
            echo ""
        fi

        if [ ${#UNTRACKED_LINES[@]} -gt 0 ]; then
            echo "## Untracked Verifications"
            echo ""
            echo "| VER | Listed Test Files |"
            echo "|-----|-------------------|"

            local entry ver_basename test_files ver_num ver_id
            for entry in "${UNTRACKED_LINES[@]}"; do
                ver_basename="${entry%%|*}"
                test_files="${entry##*|}"
                ver_num=$(echo "$ver_basename" | sed -n 's/ver_\([0-9][0-9][0-9]\(\.[0-9][0-9]\)\?\)_.*/\1/p')
                ver_id="VER-${ver_num}"
                echo "| $ver_id | \`$test_files\` |"
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
    local entry status src_file ver_basename

    for entry in "${RESULT_LINES[@]}"; do
        IFS='|' read -r status src_file ver_basename _ _ _ <<< "$entry"
        case "$status" in
            current) echo "✓ current — $src_file" ;;
            stale)   echo "⚠ stale   — $src_file" ;;
            missing) echo "✗ missing — $src_file (references $ver_basename)" ;;
        esac
    done

    for entry in "${UNTRACKED_LINES[@]}"; do
        ver_basename="${entry%%|*}"
        echo "○ untracked — $ver_basename"
    done
}

# ─── Main ─────────────────────────────────────────────────────────

scan_ver_refs
parse_test_sections
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
    echo "No Ver-ref lines found."
elif [ "$TOTAL" -eq 0 ]; then
    echo "All verification tests are current."
else
    echo "Summary: $CURRENT_COUNT current, $STALE_COUNT stale, $MISSING_COUNT missing, $UNTRACKED_COUNT untracked"
fi

exit $((TOTAL > 0 ? 1 : 0))
