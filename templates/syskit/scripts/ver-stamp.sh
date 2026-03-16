#!/bin/bash
# Update Ver-ref hashes in test files for a given verification document
# Usage: ver-stamp.sh [VER-NNN | ver_NNN_name.md]
#   No argument: stamp all VERs that have a ## Test Implementation section
#   With argument: stamp one VER
# Exit codes: 0 = all updated, 1 = warnings
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VER_DIR="$PROJECT_ROOT/doc/verification"

VER_ARG="${1:-}"

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

# ─── Cross-platform sed -i ───────────────────────────────────────

if [[ "$OSTYPE" == "darwin"* ]]; then
    sed_inplace() { sed -i '' "$@"; }
else
    sed_inplace() { sed -i "$@"; }
fi

# ─── Resolve VER argument ────────────────────────────────────────

resolve_ver() {
    local arg="$1"

    # Try direct basename match
    if [ -f "$VER_DIR/$arg" ]; then
        echo "$VER_DIR/$arg"
        return 0
    fi

    # Check for hierarchical ID (VER-NNN.NN)
    if echo "$arg" | grep -qE '[0-9]{3}\.[0-9]{2}'; then
        local num
        num=$(echo "$arg" | grep -oE '[0-9]{3}\.[0-9]{2}' | head -1)
        local matches=("$VER_DIR"/ver_${num}_*.md)
        if [ -f "${matches[0]}" ]; then
            echo "${matches[0]}"
            return 0
        fi
    else
        # Extract 3-digit number from VER-NNN, ver-NNN, etc.
        local num
        num=$(echo "$arg" | grep -oE '[0-9]{3}' | head -1)
        if [ -z "$num" ]; then
            echo "Error: cannot parse VER number from '$arg'" >&2
            return 1
        fi

        local matches=("$VER_DIR"/ver_${num}_*.md)
        if [ -f "${matches[0]}" ]; then
            echo "${matches[0]}"
            return 0
        fi
    fi

    echo "Error: no verification file found for '$arg'" >&2
    return 1
}

# ─── Stamp a single VER file ─────────────────────────────────────

TOTAL_UPDATED=0
TOTAL_WARNED=0

stamp_ver() {
    local ver_file="$1"
    local ver_basename
    ver_basename=$(basename "$ver_file")

    # Compute current hash
    local current_hash today
    current_hash=$(hash_cmd "$ver_file")
    today=$(date +%Y-%m-%d)

    echo "ver-stamp: $ver_basename"
    echo "Hash: \`$current_hash\` ($today)"
    echo ""

    # Extract test file paths from ## Test Implementation
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
    ' "$ver_file")

    if [ -z "$test_files" ]; then
        echo "No test files listed in ## Test Implementation section."
        echo ""
        return
    fi

    local updated=0
    local warned=0

    # Build set of listed files for orphan check
    declare -A listed_files

    # Process each test file
    while IFS= read -r test_path; do
        [ -z "$test_path" ] && continue
        listed_files["$test_path"]=1

        if [ ! -f "$PROJECT_ROOT/$test_path" ]; then
            echo "⚠ not found  — $test_path"
            warned=$((warned + 1))
            continue
        fi

        if grep -q "Ver-ref:.*${ver_basename}" "$PROJECT_ROOT/$test_path"; then
            # Extract existing hash to avoid unnecessary date-only changes
            local existing_hash
            existing_hash=$(grep "Ver-ref:.*${ver_basename}" "$PROJECT_ROOT/$test_path" | grep -oE '\`[0-9a-f]{16}\`' | tr -d '`' | head -1)
            if [ "$existing_hash" = "$current_hash" ]; then
                echo "· current    — $test_path"
            else
                # Update hash and date, preserving comment prefix
                sed_inplace "s|\(Ver-ref:[[:space:]]*${ver_basename}[[:space:]]*\)\`[0-9a-f]\{16\}\`[[:space:]]*[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}|\1\`${current_hash}\` ${today}|" "$PROJECT_ROOT/$test_path"
                echo "✓ updated    — $test_path"
                updated=$((updated + 1))
            fi
        else
            echo "⚠ no Ver-ref — $test_path"
            warned=$((warned + 1))
        fi
    done <<< "$test_files"

    # Scan for orphaned references
    echo ""

    local orphan_files
    orphan_files=$(git ls-files --cached --others --exclude-standard 2>/dev/null | grep -v '^\.syskit/' | xargs grep -lI "Ver-ref:.*${ver_basename}" 2>/dev/null || true)

    local orphan_found=0
    if [ -n "$orphan_files" ]; then
        while IFS= read -r orphan; do
            [ -z "$orphan" ] && continue
            if [ -z "${listed_files[$orphan]:-}" ]; then
                echo "⚠ orphan     — $orphan (has Ver-ref to $ver_basename but not in ## Test Implementation)"
                warned=$((warned + 1))
                orphan_found=$((orphan_found + 1))
            fi
        done <<< "$orphan_files"
    fi

    if [ "$orphan_found" -eq 0 ]; then
        echo "No orphaned references found."
    fi

    echo ""
    echo "Summary: $updated updated, $warned warnings"
    echo ""

    TOTAL_UPDATED=$((TOTAL_UPDATED + updated))
    TOTAL_WARNED=$((TOTAL_WARNED + warned))
}

# ─── Main ─────────────────────────────────────────────────────────

if [ -n "$VER_ARG" ]; then
    # Single VER mode
    VER_FILE=$(resolve_ver "$VER_ARG")
    stamp_ver "$VER_FILE"
else
    # All VERs mode
    found_any=false
    for f in "$VER_DIR"/ver_[0-9]*.md; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        [[ "$base" == *_000_template* ]] && continue
        found_any=true
        stamp_ver "$f"
    done

    if ! $found_any; then
        echo "No verification documents found in $VER_DIR."
        exit 0
    fi

    echo "═══════════════════════════════════════"
    echo "Total: $TOTAL_UPDATED updated, $TOTAL_WARNED warnings"
fi

exit $((TOTAL_WARNED > 0 ? 1 : 0))
