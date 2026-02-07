#!/bin/bash
# Generate install.sh from templates
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_ROOT/templates"
OUTPUT="$REPO_ROOT/install.sh"

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

PROJECT_NAME=$(basename "$(pwd)")
DATE=$(date -Iseconds)

info "Installing syskit in: $(pwd)"

# Create directory structure
info "Creating directories..."
mkdir -p doc/requirements
mkdir -p doc/interfaces
mkdir -p doc/design
mkdir -p .syskit/commands
mkdir -p .syskit/scripts
mkdir -p .syskit/analysis
mkdir -p .syskit/tasks
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
    echo "cat > \"$dest\" << 'SYSKIT_EOF'"
    
    # Escape any existing SYSKIT_EOF in the file (unlikely but safe)
    sed 's/SYSKIT_EOF/SYSKIT_EOF_ESCAPED/g' "$src"
    
    echo "SYSKIT_EOF"
    
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

# Embed doc templates (skip if exists to not overwrite user content)
for f in "$TEMPLATES_DIR/doc/requirements/"*.md; do
    name=$(basename "$f")
    embed_file "$f" "doc/requirements/$name" "644" "true" >> "$OUTPUT"
done

for f in "$TEMPLATES_DIR/doc/interfaces/"*.md; do
    name=$(basename "$f")
    embed_file "$f" "doc/interfaces/$name" "644" "true" >> "$OUTPUT"
done

for f in "$TEMPLATES_DIR/doc/design/"*.md; do
    name=$(basename "$f")
    embed_file "$f" "doc/design/$name" "644" "true" >> "$OUTPUT"
done

# Add manifest generation and completion
cat >> "$OUTPUT" << 'SCRIPT_FOOTER'

# Generate initial manifest
info "Generating manifest..."
.syskit/scripts/manifest.sh

# Create/update CLAUDE.md to reference syskit
if [ -f "CLAUDE.md" ]; then
    if ! grep -q "syskit" "CLAUDE.md"; then
        info "Adding syskit reference to CLAUDE.md"
        echo "" >> CLAUDE.md
        echo "## syskit" >> CLAUDE.md
        echo "" >> CLAUDE.md
        echo "This project uses syskit for specification-driven development." >> CLAUDE.md
        echo "See \`.syskit/AGENTS.md\` for workflow instructions." >> CLAUDE.md
    fi
else
    info "Creating CLAUDE.md"
    cat > CLAUDE.md << 'CLAUDE_EOF'
# Project Instructions

## syskit

This project uses syskit for specification-driven development.
See `.syskit/AGENTS.md` for workflow instructions.
CLAUDE_EOF
fi

info ""
info "syskit installed successfully!"
info ""
info "Next steps:"
info "  1. Create requirements:  .syskit/scripts/new-req.sh <name>"
info "  2. Create interfaces:    .syskit/scripts/new-int.sh <name>"
info "  3. Create design units:  .syskit/scripts/new-unit.sh <name>"
info "  4. Use /syskit-impact to analyze changes"
info ""
info "See .syskit/AGENTS.md for full documentation."
SCRIPT_FOOTER

chmod +x "$OUTPUT"

echo "Generated: $OUTPUT"
echo "Size: $(wc -c < "$OUTPUT") bytes"
