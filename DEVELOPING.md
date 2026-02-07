# Developing syskit

This document describes how to develop and build syskit itself.

## Repository Structure

```
syskit/
├── README.md              # User-facing documentation
├── DEVELOPING.md          # This file
├── templates/             # Source templates for installed files
│   ├── doc/
│   │   ├── requirements/
│   │   ├── interfaces/
│   │   └── design/
│   ├── syskit/
│   │   ├── AGENTS.md
│   │   ├── commands/
│   │   └── scripts/
│   └── claude/
│       └── commands/      # Claude Code slash commands
├── build/
│   └── generate-installer.sh
├── install.sh             # Generated installer (committed)
└── test/
    └── test-install.sh
```

## How It Works

syskit is distributed as a single self-extracting shell script (`install.sh`). This script contains all templates embedded as heredocs and creates the necessary directory structure when run.

The `build/generate-installer.sh` script reads all files from `templates/` and generates `install.sh`.

## Development Workflow

1. Edit templates in `templates/`
2. Run `./build/generate-installer.sh` to regenerate `install.sh`
3. Test with `./test/test-install.sh`
4. Commit both the templates and the generated `install.sh`

## Template Variables

Templates can contain variables that are substituted at install time:

- `{{PROJECT_NAME}}` — Name of the target project (directory name)
- `{{DATE}}` — Installation date (ISO format)

## Adding New Templates

1. Create the file in the appropriate location under `templates/`
2. Run the build script to regenerate the installer
3. The file will automatically be included

## Adding New Slash Commands

Slash commands live in two places:

- `templates/syskit/commands/` — Commands referenced by AGENTS.md
- `templates/claude/commands/` — Claude Code specific slash commands (`.claude/commands/`)

For Claude Code, slash commands need a frontmatter block:

```markdown
---
description: Brief description shown in command palette
arguments:
  - name: arg_name
    description: What this argument is for
    required: true
---

Command content here...
```

## Testing

The test script creates a temporary directory, runs the installer, and verifies:

- All expected directories exist
- All expected files exist
- Scripts are executable
- Manifest generation works

```bash
./test/test-install.sh
```

## Design Principles

1. **No runtime dependencies.** The installer is pure bash. Installed scripts are pure bash.

2. **Readable output.** The installer should be auditable—anyone can read install.sh and see exactly what it does.

3. **Idempotent installation.** Running the installer twice should be safe. Don't overwrite existing content files, only update tooling files.

4. **Minimal footprint.** Only install what's necessary. Prefer convention over configuration.
