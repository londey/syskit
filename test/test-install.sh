#!/bin/bash
# Test syskit installation
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALLER="$REPO_ROOT/install.sh"

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
    ".syskit/scripts/new-req.sh" \
    ".syskit/scripts/new-int.sh" \
    ".syskit/scripts/new-unit.sh" \
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
    ".syskit/scripts/new-req.sh" \
    ".syskit/scripts/new-int.sh" \
    ".syskit/scripts/new-unit.sh"
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
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
