# syskit Development Instructions

This is the syskit tool repository. syskit is a lightweight specification-driven development tool for embedded and multi-component systems.

## Repository Structure

- `templates/` — Source templates that get embedded into the installer
- `build/` — Build scripts
- `test/` — Test scripts
- `install.sh` — Generated installer (do not edit directly)

## Development Workflow

1. Edit templates in `templates/`
2. Run `./build/generate-installer.sh` to regenerate `install.sh`
3. Run `./test/test-install.sh` to verify
4. Commit both templates and generated `install.sh`

## Key Files

### Templates

- `templates/syskit/AGENTS.md` — Main AI instructions, most important file
- `templates/claude/commands/*.md` — Slash command definitions
- `templates/syskit/scripts/*.sh` — Helper scripts
- `templates/doc/**/*.md` — Document templates

### Build

- `build/generate-installer.sh` — Reads templates, generates `install.sh`

## Design Principles

1. **No runtime dependencies** — Pure bash, works anywhere
2. **Self-contained installer** — Single file, auditable
3. **Idempotent** — Safe to run multiple times
4. **Convention over configuration** — Minimal setup required

## Testing Changes

Always run the test suite before committing:

```bash
./build/generate-installer.sh
./test/test-install.sh
```

## Adding New Templates

1. Create the file in the appropriate location under `templates/`
2. The build script will automatically include it
3. For scripts that need to be executable, they're in `templates/syskit/scripts/`

## Slash Command Format

Claude Code slash commands need frontmatter:

```markdown
---
description: Brief description
arguments:
  - name: arg_name
    description: What this is
    required: true/false
---

Content here, use $ARGUMENTS.arg_name for substitution
```
