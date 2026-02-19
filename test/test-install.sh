#!/bin/bash
# Test syskit installation
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALLER="$REPO_ROOT/install_syskit.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; FAILED=1; }

FAILED=0

# Create temp directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "Testing syskit installation..."
echo "Test directory: $TEST_DIR"
echo ""

# Initialize as git repo (installer checks for this)
cd "$TEST_DIR"
git init -q

# Run installer
echo "Running installer..."
if bash "$INSTALLER"; then
    pass "Installer completed"
else
    fail "Installer failed"
    exit 1
fi

echo ""
echo "Checking directory structure..."

# Check directories
for dir in \
    "doc/requirements" \
    "doc/interfaces" \
    "doc/design" \
    ".syskit/scripts" \
    ".syskit/analysis" \
    ".syskit/tasks" \
    ".syskit/templates/doc/requirements" \
    ".syskit/templates/doc/interfaces" \
    ".syskit/templates/doc/design" \
    ".claude/commands"
do
    if [ -d "$dir" ]; then
        pass "Directory: $dir"
    else
        fail "Missing directory: $dir"
    fi
done

echo ""
echo "Checking files..."

# Check files
for file in \
    ".syskit/AGENTS.md" \
    ".syskit/manifest.md" \
    ".syskit/scripts/manifest.sh" \
    ".syskit/scripts/manifest-snapshot.sh" \
    ".syskit/scripts/manifest-check.sh" \
    ".syskit/scripts/new-req.sh" \
    ".syskit/scripts/new-int.sh" \
    ".syskit/scripts/new-unit.sh" \
    ".syskit/scripts/trace-sync.sh" \
    ".syskit/scripts/impl-check.sh" \
    ".syskit/scripts/impl-stamp.sh" \
    ".syskit/scripts/toc-update.sh" \
    ".claude/commands/syskit-impact.md" \
    ".claude/commands/syskit-propose.md" \
    ".claude/commands/syskit-plan.md" \
    ".claude/commands/syskit-implement.md" \
    ".claude/commands/syskit-guide.md" \
    "doc/requirements/states_and_modes.md" \
    "doc/requirements/quality_metrics.md" \
    "doc/requirements/req_000_template.md" \
    "doc/interfaces/int_000_template.md" \
    "doc/design/design_decisions.md" \
    "doc/design/concept_of_execution.md" \
    "doc/design/unit_000_template.md" \
    "doc/requirements/README.md" \
    "doc/interfaces/README.md" \
    "doc/design/README.md" \
    ".syskit/templates/doc/requirements/README.md" \
    ".syskit/templates/doc/interfaces/README.md" \
    ".syskit/templates/doc/design/README.md" \
    ".syskit/templates/doc/requirements/req_000_template.md" \
    ".syskit/templates/doc/requirements/quality_metrics.md" \
    ".syskit/templates/doc/requirements/states_and_modes.md" \
    ".syskit/templates/doc/interfaces/int_000_template.md" \
    ".syskit/templates/doc/design/unit_000_template.md" \
    ".syskit/templates/doc/design/concept_of_execution.md" \
    ".syskit/templates/doc/design/design_decisions.md" \
    ".syskit/templates/CLAUDE_SYSKIT.md" \
    "CLAUDE.md"
do
    if [ -f "$file" ]; then
        pass "File: $file"
    else
        fail "Missing file: $file"
    fi
done

echo ""
echo "Checking scripts are executable..."

for script in \
    ".syskit/scripts/manifest.sh" \
    ".syskit/scripts/manifest-snapshot.sh" \
    ".syskit/scripts/manifest-check.sh" \
    ".syskit/scripts/new-req.sh" \
    ".syskit/scripts/new-int.sh" \
    ".syskit/scripts/new-unit.sh" \
    ".syskit/scripts/trace-sync.sh" \
    ".syskit/scripts/impl-check.sh" \
    ".syskit/scripts/impl-stamp.sh" \
    ".syskit/scripts/toc-update.sh"
do
    if [ -x "$script" ]; then
        pass "Executable: $script"
    else
        fail "Not executable: $script"
    fi
done

echo ""
echo "Testing helper scripts..."

# Test new-req.sh
if .syskit/scripts/new-req.sh test_requirement > /dev/null; then
    if [ -f "doc/requirements/req_001_test_requirement.md" ]; then
        pass "new-req.sh creates requirement"
    else
        fail "new-req.sh did not create expected file"
    fi
else
    fail "new-req.sh failed"
fi

# Test new-int.sh
if .syskit/scripts/new-int.sh test_interface > /dev/null; then
    if [ -f "doc/interfaces/int_001_test_interface.md" ]; then
        pass "new-int.sh creates interface"
    else
        fail "new-int.sh did not create expected file"
    fi
else
    fail "new-int.sh failed"
fi

# Test new-unit.sh
if .syskit/scripts/new-unit.sh test_unit > /dev/null; then
    if [ -f "doc/design/unit_001_test_unit.md" ]; then
        pass "new-unit.sh creates unit"
    else
        fail "new-unit.sh did not create expected file"
    fi
else
    fail "new-unit.sh failed"
fi

# Test manifest.sh
if .syskit/scripts/manifest.sh > /dev/null; then
    # Check manifest includes new files
    if grep -q "req_001_test_requirement.md" .syskit/manifest.md; then
        pass "manifest.sh includes new requirement"
    else
        fail "manifest.sh missing new requirement"
    fi
else
    fail "manifest.sh failed"
fi

# Test manifest-snapshot.sh
mkdir -p .syskit/test-analysis
if .syskit/scripts/manifest-snapshot.sh .syskit/test-analysis doc/requirements/req_001_test_requirement.md > /dev/null; then
    if [ -f ".syskit/test-analysis/snapshot.md" ]; then
        if grep -q "req_001_test_requirement.md" .syskit/test-analysis/snapshot.md; then
            pass "manifest-snapshot.sh creates snapshot with file hash"
        else
            fail "manifest-snapshot.sh snapshot missing expected file"
        fi
    else
        fail "manifest-snapshot.sh did not create snapshot.md"
    fi
else
    fail "manifest-snapshot.sh failed"
fi

# Test manifest-check.sh (unchanged file should pass)
if .syskit/scripts/manifest-check.sh .syskit/test-analysis/snapshot.md > /dev/null 2>&1; then
    pass "manifest-check.sh reports fresh snapshot"
else
    fail "manifest-check.sh incorrectly reported stale snapshot"
fi

# Test manifest-check.sh (modified file should fail)
echo "modified content" >> doc/requirements/req_001_test_requirement.md
if .syskit/scripts/manifest-check.sh .syskit/test-analysis/snapshot.md > /dev/null 2>&1; then
    fail "manifest-check.sh did not detect modified file"
else
    pass "manifest-check.sh detects modified file"
fi

rm -rf .syskit/test-analysis

echo ""
echo "Testing toc-update..."

# TOC should include newly created documents
.syskit/scripts/toc-update.sh > /dev/null 2>&1
if grep -q "req_001_test_requirement.md" doc/requirements/README.md; then
    pass "toc-update.sh adds new requirement to TOC"
else
    fail "toc-update.sh did not add requirement to TOC"
fi

if grep -q "int_001_test_interface.md" doc/interfaces/README.md; then
    pass "toc-update.sh adds new interface to TOC"
else
    fail "toc-update.sh did not add interface to TOC"
fi

if grep -q "unit_001_test_unit.md" doc/design/README.md; then
    pass "toc-update.sh adds new unit to TOC"
else
    fail "toc-update.sh did not add unit to TOC"
fi

# TOC should not include template files
if grep -q "req_000_template.md" doc/requirements/README.md; then
    fail "toc-update.sh incorrectly included template in TOC"
else
    pass "toc-update.sh excludes template files from TOC"
fi

echo ""
echo "Testing trace-sync..."

# Undo the modification from manifest test
git checkout -- doc/requirements/req_001_test_requirement.md 2>/dev/null || true

# Add cross-reference: REQ-001 allocated to UNIT-001
sed -i 's/- UNIT-NNN (<unit name>)/- UNIT-001 (Test Unit)/' doc/requirements/req_001_test_requirement.md

# Check mode should find missing back-reference
if .syskit/scripts/trace-sync.sh 2>/dev/null | grep -q "MISSING"; then
    pass "trace-sync.sh detects missing back-reference"
else
    fail "trace-sync.sh did not detect missing back-reference"
fi

# Fix mode should resolve it
if .syskit/scripts/trace-sync.sh --fix 2>/dev/null | grep -q "FIXED"; then
    pass "trace-sync.sh --fix adds missing back-reference"
else
    fail "trace-sync.sh --fix did not add back-reference"
fi

# Verify: no more MISSING after fix (orphans may remain)
if .syskit/scripts/trace-sync.sh 2>/dev/null | grep -q "MISSING"; then
    fail "trace-sync.sh still reports missing references after fix"
else
    pass "trace-sync.sh confirms no missing references after fix"
fi

echo ""
echo "Testing new-req.sh --parent flag..."

# Create a child requirement with --parent (hierarchical numbering: REQ-001.01)
if .syskit/scripts/new-req.sh --parent REQ-001 child_requirement > /dev/null; then
    if [ -f doc/requirements/req_001.01_child_requirement.md ]; then
        if grep -q "REQ-001" doc/requirements/req_001.01_child_requirement.md; then
            pass "new-req.sh --parent creates hierarchical child (REQ-001.01)"
        else
            fail "new-req.sh --parent did not set parent reference"
        fi
    else
        fail "new-req.sh --parent did not create hierarchical filename (expected req_001.01_child_requirement.md)"
    fi
else
    fail "new-req.sh --parent failed"
fi

echo ""
echo "Testing new-int.sh --parent flag..."

# Create a child interface with --parent (hierarchical numbering: INT-001.01)
if .syskit/scripts/new-int.sh --parent INT-001 child_interface > /dev/null; then
    if [ -f doc/interfaces/int_001.01_child_interface.md ]; then
        if grep -q "INT-001.01" doc/interfaces/int_001.01_child_interface.md; then
            pass "new-int.sh --parent creates hierarchical child (INT-001.01)"
        else
            fail "new-int.sh --parent did not set correct ID in file"
        fi
    else
        fail "new-int.sh --parent did not create hierarchical filename (expected int_001.01_child_interface.md)"
    fi
else
    fail "new-int.sh --parent failed"
fi

echo ""
echo "Testing new-unit.sh --parent flag..."

# Create a child unit with --parent (hierarchical numbering: UNIT-001.01)
if .syskit/scripts/new-unit.sh --parent UNIT-001 child_unit > /dev/null; then
    if [ -f doc/design/unit_001.01_child_unit.md ]; then
        if grep -q "UNIT-001.01" doc/design/unit_001.01_child_unit.md; then
            pass "new-unit.sh --parent creates hierarchical child (UNIT-001.01)"
        else
            fail "new-unit.sh --parent did not set correct ID in file"
        fi
    else
        fail "new-unit.sh --parent did not create hierarchical filename (expected unit_001.01_child_unit.md)"
    fi
else
    fail "new-unit.sh --parent failed"
fi

echo ""
echo "Testing impl-check and impl-stamp..."

# Set up: edit unit_001's ## Implementation section to list a source file
sed -i 's/- `<filepath>`: <description>/- `src\/test_unit.rs`: Main implementation/' doc/design/unit_001_test_unit.md

# Compute the current hash of the unit file
if command -v sha256sum &> /dev/null; then
    UNIT1_HASH=$(sha256sum doc/design/unit_001_test_unit.md | cut -c1-16)
else
    UNIT1_HASH=$(shasum -a 256 doc/design/unit_001_test_unit.md | cut -c1-16)
fi

# Create a source file with a matching Spec-ref
mkdir -p src
cat > src/test_unit.rs << SRCEOF
// Spec-ref: unit_001_test_unit.md \`${UNIT1_HASH}\` $(date +%Y-%m-%d)
fn main() {}
SRCEOF
git add src/test_unit.rs

# impl-check should report current
if .syskit/scripts/impl-check.sh UNIT-001 2>/dev/null | grep -q "current"; then
    pass "impl-check.sh reports current for matching hash"
else
    fail "impl-check.sh did not report current"
fi

# Modify the unit file to make hash stale
echo "<!-- additional design note -->" >> doc/design/unit_001_test_unit.md

# impl-check should report stale
if .syskit/scripts/impl-check.sh UNIT-001 2>/dev/null | grep -q "stale"; then
    pass "impl-check.sh detects stale after unit file change"
else
    fail "impl-check.sh did not detect stale"
fi

# impl-stamp should update the hash
if .syskit/scripts/impl-stamp.sh UNIT-001 2>/dev/null | grep -q "updated"; then
    pass "impl-stamp.sh updates Spec-ref hash"
else
    fail "impl-stamp.sh did not update hash"
fi

# impl-check should now report current again
if .syskit/scripts/impl-check.sh UNIT-001 2>/dev/null | grep -q "current"; then
    pass "impl-check.sh reports current after stamp"
else
    fail "impl-check.sh still reports stale after stamp"
fi

echo ""
echo "Testing idempotent installation..."

SYSKIT_COUNT_BEFORE=$(grep -c "syskit" CLAUDE.md || true)

# Run installer again
if bash "$INSTALLER" > /dev/null 2>&1; then
    pass "Second installation succeeded"

    # Check we didn't duplicate content in CLAUDE.md
    SYSKIT_COUNT_AFTER=$(grep -c "syskit" CLAUDE.md || true)
    if [ "$SYSKIT_COUNT_AFTER" -eq "$SYSKIT_COUNT_BEFORE" ]; then
        pass "CLAUDE.md not duplicated"
    else
        fail "CLAUDE.md has duplicate syskit references (before: $SYSKIT_COUNT_BEFORE, after: $SYSKIT_COUNT_AFTER)"
    fi
else
    fail "Second installation failed"
fi

echo ""
echo "Testing template overwrite behavior..."

# Modify a copy-template (should be overwritten on re-install)
echo "user modification" > doc/requirements/req_000_template.md
# Modify a framework doc (should NOT be overwritten on re-install)
echo "user customization" > doc/requirements/quality_metrics.md
# Modify a README (should NOT be overwritten on re-install)
echo "user readme edit" > doc/requirements/README.md

# Run installer again
if bash "$INSTALLER" > /dev/null 2>&1; then
    pass "Third installation succeeded"
else
    fail "Third installation failed"
fi

# Copy-template should be restored to original
if grep -q "user modification" doc/requirements/req_000_template.md; then
    fail "Copy-template was not overwritten on re-install"
else
    pass "Copy-template overwritten on re-install"
fi

# Framework doc should keep user content
if grep -q "user customization" doc/requirements/quality_metrics.md; then
    pass "Framework doc preserved user customization"
else
    fail "Framework doc was overwritten on re-install"
fi

# README should keep user content
if grep -q "user readme edit" doc/requirements/README.md; then
    pass "README preserved user customization"
else
    fail "README was overwritten on re-install"
fi

# .syskit/templates/ should always have latest clean version
if grep -q "REQ-000" .syskit/templates/doc/requirements/req_000_template.md; then
    pass "Reference template in .syskit/templates/ has latest content"
else
    fail "Reference template in .syskit/templates/ missing or incorrect"
fi

echo ""
echo "Testing CLAUDE.md markers and updates..."

# Verify markers exist from fresh install
if grep -q "<!-- syskit-start -->" CLAUDE.md && grep -q "<!-- syskit-end -->" CLAUDE.md; then
    pass "CLAUDE.md has syskit update markers"
else
    fail "CLAUDE.md missing syskit update markers"
fi

# Verify behavioral guidance content (not just command reference)
if grep -q "Spec-ref" CLAUDE.md; then
    pass "CLAUDE.md has behavioral guidance about Spec-ref"
else
    fail "CLAUDE.md missing behavioral guidance"
fi

# Test: re-install replaces section between markers
sed -i 's/specification-driven/TAMPERED/' CLAUDE.md
if grep -q "TAMPERED" CLAUDE.md; then
    if bash "$INSTALLER" > /dev/null 2>&1; then
        if grep -q "TAMPERED" CLAUDE.md; then
            fail "CLAUDE.md syskit section was not updated on re-install"
        else
            pass "CLAUDE.md syskit section updated on re-install"
        fi
    else
        fail "Installer failed during CLAUDE.md update test"
    fi
else
    fail "sed tamper did not work (test setup error)"
fi

# Test: existing CLAUDE.md without syskit gets section appended
echo "# My Project" > CLAUDE.md
echo "" >> CLAUDE.md
echo "Some existing content." >> CLAUDE.md
if bash "$INSTALLER" > /dev/null 2>&1; then
    if grep -q "My Project" CLAUDE.md && grep -q "<!-- syskit-start -->" CLAUDE.md; then
        pass "Existing CLAUDE.md gets syskit section appended"
    else
        fail "Existing CLAUDE.md was not properly updated"
    fi
else
    fail "Installer failed during append test"
fi

# Test: section preserves surrounding content
if grep -q "Some existing content" CLAUDE.md; then
    pass "Existing CLAUDE.md content preserved after append"
else
    fail "Existing CLAUDE.md content was lost"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
