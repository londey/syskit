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
mkdir -p .syskit/prompts
mkdir -p .syskit/ref
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

# Embed scripts (executable, sorted for reproducible output)
for f in $(printf '%s\n' "$TEMPLATES_DIR/syskit/scripts/"*.sh | LC_COLLATE=C sort); do
    name=$(basename "$f")
    embed_file "$f" ".syskit/scripts/$name" "755" >> "$OUTPUT"
done

# Embed subagent prompt templates (sorted for reproducible output)
for f in $(printf '%s\n' "$TEMPLATES_DIR/syskit/prompts/"*.md | LC_COLLATE=C sort); do
    name=$(basename "$f")
    embed_file "$f" ".syskit/prompts/$name" >> "$OUTPUT"
done

# Embed reference files (sorted for reproducible output)
for f in $(printf '%s\n' "$TEMPLATES_DIR/syskit/ref/"*.md | LC_COLLATE=C sort); do
    name=$(basename "$f")
    embed_file "$f" ".syskit/ref/$name" >> "$OUTPUT"
done

# Embed Claude commands (sorted for reproducible output)
for f in $(printf '%s\n' "$TEMPLATES_DIR/claude/commands/"*.md | LC_COLLATE=C sort); do
    name=$(basename "$f")
    embed_file "$f" ".claude/commands/$name" >> "$OUTPUT"
done

# Embed CLAUDE.md syskit section template
embed_file "$TEMPLATES_DIR/claude/CLAUDE_SYSKIT.md" ".syskit/templates/CLAUDE_SYSKIT.md" "644" >> "$OUTPUT"

# Embed doc templates to .syskit/templates/ (always overwrite — single source of truth)
embed_file "$TEMPLATES_DIR/doc/requirements/req_000_template.md" ".syskit/templates/doc/requirements/req_000_template.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/requirements/quality_metrics.md" ".syskit/templates/doc/requirements/quality_metrics.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/requirements/states_and_modes.md" ".syskit/templates/doc/requirements/states_and_modes.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/interfaces/int_000_template.md" ".syskit/templates/doc/interfaces/int_000_template.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/design/unit_000_template.md" ".syskit/templates/doc/design/unit_000_template.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/design/concept_of_execution.md" ".syskit/templates/doc/design/concept_of_execution.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/design/design_decisions.md" ".syskit/templates/doc/design/design_decisions.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/requirements/README.md" ".syskit/templates/doc/requirements/README.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/interfaces/README.md" ".syskit/templates/doc/interfaces/README.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/design/README.md" ".syskit/templates/doc/design/README.md" "644" >> "$OUTPUT"
embed_file "$TEMPLATES_DIR/doc/design/ARCHITECTURE.md" ".syskit/templates/doc/design/ARCHITECTURE.md" "644" >> "$OUTPUT"

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
    "doc/design/design_decisions.md" \
    "doc/requirements/README.md" \
    "doc/interfaces/README.md" \
    "doc/design/README.md"
do
    if [ ! -f "$tmpl" ]; then
        info "Creating $tmpl"
        cp ".syskit/templates/$tmpl" "$tmpl"
    else
        info "Skipping $tmpl (already exists)"
    fi
done

# ARCHITECTURE.md: only create if missing (user-owned after initial install)
if [ ! -f "ARCHITECTURE.md" ]; then
    info "Creating ARCHITECTURE.md"
    cp ".syskit/templates/doc/design/ARCHITECTURE.md" "ARCHITECTURE.md"
else
    info "Skipping ARCHITECTURE.md (already exists)"
fi
COPY_TEMPLATES

# Add manifest generation and completion
cat >> "$OUTPUT" << 'SCRIPT_FOOTER'

# Update table of contents in README files
info "Updating doc README table of contents..."
.syskit/scripts/toc-update.sh

# Update architecture diagram if ARCHITECTURE.md has guard markers
if grep -q '<!-- syskit-arch-start -->' "ARCHITECTURE.md" 2>/dev/null; then
    info "Updating ARCHITECTURE.md diagram..."
    .syskit/scripts/arch-update.sh
fi

# Generate initial manifest
info "Generating manifest..."
.syskit/scripts/manifest.sh

# Create/update CLAUDE.md to reference syskit
SYSKIT_MD=".syskit/templates/CLAUDE_SYSKIT.md"

if [ -f "CLAUDE.md" ]; then
    if grep -q "<!-- syskit-start -->" "CLAUDE.md"; then
        info "Updating syskit section in CLAUDE.md"
        awk -v sf="$SYSKIT_MD" '
            /<!-- syskit-start -->/ {
                skip=1
                print "<!-- syskit-start -->"
                while ((getline line < sf) > 0) print line
                close(sf)
                print "<!-- syskit-end -->"
                next
            }
            /<!-- syskit-end -->/ { skip=0; next }
            !skip
        ' CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
    elif ! grep -q "## syskit" "CLAUDE.md"; then
        info "Adding syskit section to CLAUDE.md"
        {
            echo ""
            echo "<!-- syskit-start -->"
            cat "$SYSKIT_MD"
            echo "<!-- syskit-end -->"
        } >> CLAUDE.md
    else
        warn "CLAUDE.md has a syskit section without update markers."
        warn "To enable automatic updates, wrap it with <!-- syskit-start --> and <!-- syskit-end -->"
    fi
else
    info "Creating CLAUDE.md"
    {
        echo "# Project Instructions"
        echo ""
        echo "<!-- syskit-start -->"
        cat "$SYSKIT_MD"
        echo "<!-- syskit-end -->"
    } > CLAUDE.md
fi

info ""
info "syskit installed successfully!"
info ""
info "Next steps:"
info "  Run /syskit-guide for an interactive walkthrough"
info ""
info "To allow Claude Code to run syskit scripts without prompting,"
info "add this to .claude/settings.local.json under permissions.allow:"
info ""
echo '  "Bash(.syskit/scripts/*:*)"'
info ""
info "See .syskit/AGENTS.md for full documentation."
SCRIPT_FOOTER

chmod +x "$OUTPUT"

echo "Generated: $OUTPUT"
echo "Size: $(wc -c < "$OUTPUT") bytes"
