#!/bin/bash
# Update the auto-generated section of ARCHITECTURE.md
# Parses doc/design/unit_*.md files to generate a Mermaid block diagram
# and a unit summary table between syskit-arch guard tags.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ARCH_FILE="$PROJECT_ROOT/ARCHITECTURE.md"
UNIT_DIR="$PROJECT_ROOT/doc/design"

cd "$PROJECT_ROOT"

if [ ! -f "$ARCH_FILE" ]; then
    echo "ARCHITECTURE.md not found." >&2
    exit 1
fi

if ! grep -q '<!-- syskit-arch-start -->' "$ARCH_FILE"; then
    echo "ARCHITECTURE.md has no <!-- syskit-arch-start --> marker. Cannot update." >&2
    exit 1
fi

# Require bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: bash 4+ required (found ${BASH_VERSION})" >&2
    exit 1
fi

# ─── Section Parser (same pattern as trace-sync.sh) ──────────────

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

# Extract first non-empty, non-placeholder line from ## Purpose
purpose_text() { # <file>
    section_lines "$1" "## Purpose" 2 \
        | grep -v '^\s*$' \
        | grep -v '^<' \
        | head -1 \
        | sed 's/^ *//'
}

# ─── Data Collection ─────────────────────────────────────────────

INT_PAT='INT-[0-9]{3}(\.[0-9]{2})?'

declare -a UNIT_IDS=()
declare -A UNIT_TITLE
declare -A UNIT_PURPOSE
declare -A UNIT_PROVIDES
declare -A UNIT_CONSUMES
declare -A UNIT_IS_CHILD
declare -A UNIT_PARENT

for f in $(printf '%s\n' "$UNIT_DIR"/unit_*.md 2>/dev/null | LC_COLLATE=C sort); do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [[ "$base" == *_000_template* ]] && continue

    # Extract UNIT ID and title from H1
    h1=$(head -1 "$f")
    id=$(echo "$h1" | grep -oE 'UNIT-[0-9]{3}(\.[0-9]{2})?' || true)
    [ -z "$id" ] && continue

    title=$(echo "$h1" | sed "s/^# *${id}: *//")

    # Detect child vs parent
    if [[ "$id" =~ ^UNIT-([0-9]{3})\.[0-9]{2}$ ]]; then
        UNIT_IS_CHILD["$id"]="true"
        UNIT_PARENT["$id"]="UNIT-${BASH_REMATCH[1]}"
    else
        UNIT_IS_CHILD["$id"]="false"
    fi

    UNIT_IDS+=("$id")
    UNIT_TITLE["$id"]="$title"
    UNIT_PURPOSE["$id"]=$(purpose_text "$f")
    UNIT_PROVIDES["$id"]=$(section_ids "$f" "### Provides" 3 "$INT_PAT")
    UNIT_CONSUMES["$id"]=$(section_ids "$f" "### Consumes" 3 "$INT_PAT")
done

# ─── Build Interface Maps ────────────────────────────────────────

declare -A INT_PROVIDER    # INT-NNN -> UNIT-NNN
declare -A INT_CONSUMERS   # INT-NNN -> space-separated UNIT-NNN list

for id in "${UNIT_IDS[@]}"; do
    for int_id in ${UNIT_PROVIDES[$id]:-}; do
        INT_PROVIDER["$int_id"]="$id"
    done
    for int_id in ${UNIT_CONSUMES[$id]:-}; do
        INT_CONSUMERS["$int_id"]="${INT_CONSUMERS[$int_id]:-}${INT_CONSUMERS[$int_id]:+ }$id"
    done
done

# ─── Generate Content ────────────────────────────────────────────

# Helper: convert UNIT-NNN or UNIT-NNN.NN to a valid Mermaid node name
node_name() {
    echo "$1" | tr '.' '_' | tr '-' '_'
}

CONTENT_TMP=$(mktemp)
trap 'rm -f "$CONTENT_TMP"' EXIT

{
    # ── Mermaid Diagram ──
    echo "### Block Diagram"
    echo ""
    echo '```mermaid'
    echo "flowchart LR"

    if [ ${#UNIT_IDS[@]} -eq 0 ]; then
        echo "    %% No design units found"
    else
        # Emit nodes: parents with children as subgraphs, others as plain nodes
        for id in "${UNIT_IDS[@]}"; do
            [ "${UNIT_IS_CHILD[$id]}" = "true" ] && continue

            node=$(node_name "$id")

            # Check if this unit has children
            has_children=false
            for cid in "${UNIT_IDS[@]}"; do
                if [ "${UNIT_PARENT[$cid]:-}" = "$id" ]; then
                    has_children=true
                    break
                fi
            done

            if $has_children; then
                echo "    subgraph ${node}[\"${id}: ${UNIT_TITLE[$id]}\"]"
                for cid in "${UNIT_IDS[@]}"; do
                    [ "${UNIT_PARENT[$cid]:-}" = "$id" ] || continue
                    c_node=$(node_name "$cid")
                    echo "        ${c_node}[\"${cid}: ${UNIT_TITLE[$cid]}\"]"
                done
                echo "    end"
            else
                echo "    ${node}[\"${id}: ${UNIT_TITLE[$id]}\"]"
            fi
        done

        # Emit interface edges
        for int_id in $(echo "${!INT_PROVIDER[@]}" | tr ' ' '\n' | LC_COLLATE=C sort); do
            provider="${INT_PROVIDER[$int_id]}"
            for consumer in ${INT_CONSUMERS[$int_id]:-}; do
                p_node=$(node_name "$provider")
                c_node=$(node_name "$consumer")
                echo "    ${p_node} -->|${int_id}| ${c_node}"
            done
        done
    fi

    echo '```'
    echo ""

    # ── Unit Summary Table ──
    echo "### Software Units"
    echo ""

    if [ ${#UNIT_IDS[@]} -eq 0 ]; then
        echo "*No design units found.*"
    else
        echo "| Unit | Title | Purpose |"
        echo "|------|-------|---------|"
        for id in "${UNIT_IDS[@]}"; do
            purpose="${UNIT_PURPOSE[$id]:-—}"
            [ -z "$purpose" ] && purpose="—"
            echo "| ${id} | ${UNIT_TITLE[$id]} | ${purpose} |"
        done
    fi
} > "$CONTENT_TMP"

# ─── Replace Guard Section ───────────────────────────────────────

TMP="${ARCH_FILE}.tmp"

awk -v sf="$CONTENT_TMP" '
    /<!-- syskit-arch-start -->/ {
        skip=1
        print "<!-- syskit-arch-start -->"
        while ((getline line < sf) > 0) print line
        close(sf)
        print "<!-- syskit-arch-end -->"
        next
    }
    /<!-- syskit-arch-end -->/ { skip=0; next }
    !skip
' "$ARCH_FILE" > "$TMP" && mv "$TMP" "$ARCH_FILE"

echo "ARCHITECTURE.md updated."
