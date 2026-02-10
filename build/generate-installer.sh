#!/bin/bash
# Generate install_syskit.sh from templates
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_ROOT/templates"
OUTPUT="$REPO_ROOT/install_syskit.sh"

echo "Generating installer from templates..."

cat > "$OUTPUT" << 'SCRIPT_HEADER'
#!/bin/bash
# syskit installer
# Generated - do not edit directly. Modify templates/ and run build/generate-installer.sh
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[syskit]${NC} $1"; }
warn() { echo -e "${YELLOW}[syskit]${NC} $1"; }
error() { echo -e "${RED}[syskit]${NC} $1"; exit 1; }

# Check we're in a reasonable location
if [ ! -d ".git" ] && [ "$1" != "--force" ]; then
    warn "Not in a git repository root. Use --force to install anyway."
    exit 1
fi

info "Installing syskit in: $(pwd)"

# Create directory structure
info "Creating directories..."
mkdir -p doc/requirements
mkdir -p doc/interfaces
mkdir -p doc/design
mkdir -p .syskit/scripts
mkdir -p .syskit/analysis
mkdir -p .syskit/tasks
mkdir -p .syskit/templates/doc/requirements
mkdir -p .syskit/templates/doc/interfaces
mkdir -p .syskit/templates/doc/design
mkdir -p .claude/commands

SCRIPT_HEADER

# Function to embed a file
embed_file() {
    local src=$1
    local dest=$2
    local mode=${3:-644}
    local skip_if_exists=${4:-false}
    
    echo ""
    echo "# --- $dest ---"
    
    if [ "$skip_if_exists" = "true" ]; then
        echo "if [ ! -f \"$dest\" ]; then"
    fi
    
    echo "info \"Creating $dest\""
    echo "cat > \"$dest\" << '__SYSKIT_TEMPLATE_END__'"
    cat "$src"
    echo "__SYSKIT_TEMPLATE_END__"
    
    if [ "$mode" = "755" ]; then
        echo "chmod +x \"$dest\""
    fi
    
    if [ "$skip_if_exists" = "true" ]; then
        echo "else"
        echo "    info \"Skipping $dest (already exists)\""
        echo "fi"
    fi
}

# Embed AGENTS.md
embed_file "$TEMPLATES_DIR/syskit/AGENTS.md" ".syskit/AGENTS.md" >> "$OUTPUT"

# Embed scripts (executable)
for f in "$TEMPLATES_DIR/syskit/scripts/"*.sh; do
    name=$(basename "$f")
    embed_file "$f" ".syskit/scripts/$name" "755" >> "$OUTPUT"
done

# Embed Claude commands
for f in "$TEMPLATES_DIR/claude/commands/"*.md; do
    name=$(basename "$f")
    embed_file "$f" ".claude/commands/$name" >> "$OUTPUT"
done

# Embed doc templates to .syskit/templates/ (always overwrite — single source of truth)
embed_file "$TEMPLATES_DIR/doc/requirements/req_000_template.md" ".syskit/templates/doc/requirements/req_000_template.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/requirements/quality_metrics.md" ".syskit/templates/doc/requirements/quality_metrics.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/requirements/states_and_modes.md" ".syskit/templates/doc/requirements/states_and_modes.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/interfaces/int_000_template.md" ".syskit/templates/doc/interfaces/int_000_template.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/design/unit_000_template.md" ".syskit/templates/doc/design/unit_000_template.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/design/concept_of_execution.md" ".syskit/templates/doc/design/concept_of_execution.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/design/design_decisions.md" ".syskit/templates/doc/design/design_decisions.md" "644" >> "$OUTPUT"

# Copy templates from .syskit/templates/ to doc/
# Copy-templates: always overwrite (users copy these, not edit originals)
# Framework docs: skip if exists (contain user content)
cat >> "$OUTPUT" << 'COPY_TEMPLATES'

# Copy-templates: always overwrite
info "Updating copy-templates in doc/..."
cp .syskit/templates/doc/requirements/req_000_template.md doc/requirements/req_000_template.md
cp .syskit/templates/doc/interfaces/int_000_template.md doc/interfaces/int_000_template.md
cp .syskit/templates/doc/design/unit_000_template.md doc/design/unit_000_template.md

# Framework docs: only create if missing
for tmpl in \
    "doc/requirements/quality_metrics.md" \
    "doc/requirements/states_and_modes.md" \
    "doc/design/concept_of_execution.md" \
    "doc/design/design_decisions.md"
do
    if [ ! -f "$tmpl" ]; then
        info "Creating $tmpl"
        cp ".syskit/templates/$tmpl" "$tmpl"
    else
        info "Skipping $tmpl (already exists)"
    fi
done
COPY_TEMPLATES

# Add manifest generation and completion
cat >> "$OUTPUT" << 'SCRIPT_FOOTER'

# Generate initial manifest
info "Generating manifest..."
.syskit/scripts/manifest.sh

# Create/update CLAUDE.md to reference syskit
if [ -f "CLAUDE.md" ]; then
    if ! grep -q "syskit" "CLAUDE.md"; then
        info "Adding syskit reference to CLAUDE.md"
        cat >> CLAUDE.md << 'CLAUDE_APPEND_EOF'

## syskit

This project uses syskit for specification-driven development.

**Before any syskit workflow, read `.syskit/AGENTS.md` for full instructions.**

Quick reference:
- `/syskit-guide` — Interactive onboarding (start here if new)
- `/syskit-impact <change>` — Analyze impact of a proposed change
- `/syskit-propose` — Propose spec modifications based on impact analysis
- `/syskit-plan` — Create implementation task breakdown
- `/syskit-implement` — Execute planned tasks

Specifications live in `doc/` (requirements, interfaces, design).
Working documents live in `.syskit/` (analysis, tasks, manifest).
CLAUDE_APPEND_EOF
    fi
else
    info "Creating CLAUDE.md"
    cat > CLAUDE.md << 'CLAUDE_EOF'
# Project Instructions

## syskit

This project uses syskit for specification-driven development.

**Before any syskit workflow, read `.syskit/AGENTS.md` for full instructions.**

Quick reference:
- `/syskit-guide` — Interactive onboarding (start here if new)
- `/syskit-impact <change>` — Analyze impact of a proposed change
- `/syskit-propose` — Propose spec modifications based on impact analysis
- `/syskit-plan` — Create implementation task breakdown
- `/syskit-implement` — Execute planned tasks

Specifications live in `doc/` (requirements, interfaces, design).
Working documents live in `.syskit/` (analysis, tasks, manifest).
CLAUDE_EOF
fi

info ""
info "syskit installed successfully!"
info ""
info "Next steps:"
info "  Run /syskit-guide for an interactive walkthrough"
info ""
info "See .syskit/AGENTS.md for full documentation."
SCRIPT_FOOTER

chmod +x "$OUTPUT"

echo "Generated: $OUTPUT"
echo "Size: $(wc -c < "$OUTPUT") bytes"
