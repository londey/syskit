#!/bin/bash
# Update Spec-ref hashes in implementation files for a given design unit
# Usage: impl-stamp.sh <UNIT-NNN | unit_NNN_name.md>
# Exit codes: 0 = all updated, 1 = warnings
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UNIT_DIR="$PROJECT_ROOT/doc/design"

UNIT_ARG="${1:-}"

if [ -z "$UNIT_ARG" ]; then
    echo "Usage: impl-stamp.sh <UNIT-NNN | unit_NNN_name.md>" >&2
    exit 1
fi

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

# ─── Resolve unit argument ───────────────────────────────────────

resolve_unit() {
    local arg="$1"

    # Try direct basename match
    if [ -f "$UNIT_DIR/$arg" ]; then
        echo "$UNIT_DIR/$arg"
        return 0
    fi

    # Extract 3-digit number from UNIT-NNN, unit-NNN, etc.
    local num
    num=$(echo "$arg" | grep -oE '[0-9]{3}' | head -1)
    if [ -z "$num" ]; then
        echo "Error: cannot parse unit number from '$arg'" >&2
        return 1
    fi

    local matches=("$UNIT_DIR"/unit_${num}_*.md)
    if [ -f "${matches[0]}" ]; then
        echo "${matches[0]}"
        return 0
    fi

    echo "Error: no unit file found for '$arg'" >&2
    return 1
}

UNIT_FILE=$(resolve_unit "$UNIT_ARG")
UNIT_BASENAME=$(basename "$UNIT_FILE")

# ─── Compute current hash ────────────────────────────────────────

CURRENT_HASH=$(hash_cmd "$UNIT_FILE")
TODAY=$(date +%Y-%m-%d)

echo "impl-stamp: $UNIT_BASENAME"
echo "Hash: \`$CURRENT_HASH\` ($TODAY)"
echo ""

# ─── Extract implementation file paths from ## Implementation ─────

IMPL_FILES=$(awk '
    BEGIN { found = 0 }
    $0 == "## Implementation" { found = 1; next }
    found && /^#/ { match($0, /^#+/); if (RLENGTH <= 2) exit }
    found && /^- `[^`]+`/ {
        match($0, /`[^`]+`/)
        path = substr($0, RSTART+1, RLENGTH-2)
        if (path !~ /[<>]/) print path
    }
' "$UNIT_FILE")

if [ -z "$IMPL_FILES" ]; then
    echo "No implementation files listed in ## Implementation section."
    exit 0
fi

UPDATED=0
WARNED=0

# ─── Build set of listed files for orphan check ──────────────────

declare -A LISTED_FILES

# ─── Process each implementation file ─────────────────────────────

while IFS= read -r impl_path; do
    [ -z "$impl_path" ] && continue
    LISTED_FILES["$impl_path"]=1

    if [ ! -f "$PROJECT_ROOT/$impl_path" ]; then
        echo "⚠ not found  — $impl_path"
        WARNED=$((WARNED + 1))
        continue
    fi

    if grep -q "Spec-ref:.*${UNIT_BASENAME}" "$PROJECT_ROOT/$impl_path"; then
        # Update hash and date, preserving comment prefix
        sed_inplace "s|\(Spec-ref:[[:space:]]*${UNIT_BASENAME}[[:space:]]*\)\`[0-9a-f]\{16\}\`[[:space:]]*[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}|\1\`${CURRENT_HASH}\` ${TODAY}|" "$PROJECT_ROOT/$impl_path"
        echo "✓ updated    — $impl_path"
        UPDATED=$((UPDATED + 1))
    else
        echo "⚠ no Spec-ref — $impl_path"
        WARNED=$((WARNED + 1))
    fi
done <<< "$IMPL_FILES"

# ─── Scan for orphaned references ─────────────────────────────────

echo ""

ORPHAN_FILES=$(git ls-files --cached --others --exclude-standard 2>/dev/null | xargs grep -lI "Spec-ref:.*${UNIT_BASENAME}" 2>/dev/null || true)

ORPHAN_FOUND=0
if [ -n "$ORPHAN_FILES" ]; then
    while IFS= read -r orphan; do
        [ -z "$orphan" ] && continue
        if [ -z "${LISTED_FILES[$orphan]:-}" ]; then
            echo "⚠ orphan     — $orphan (has Spec-ref to $UNIT_BASENAME but not in ## Implementation)"
            WARNED=$((WARNED + 1))
            ORPHAN_FOUND=$((ORPHAN_FOUND + 1))
        fi
    done <<< "$ORPHAN_FILES"
fi

if [ "$ORPHAN_FOUND" -eq 0 ]; then
    echo "No orphaned references found."
fi

# ─── Summary ──────────────────────────────────────────────────────

echo ""
echo "Summary: $UPDATED updated, $WARNED warnings"

exit $((WARNED > 0 ? 1 : 0))
