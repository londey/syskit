# syskit

Lightweight specification-driven development for embedded and multi-component systems.

syskit installs as a set of files in your repository—no runtime, no server, no dependencies. Your AI coding assistant (Claude Code, Cursor, etc.) reads the templates and follows the workflows.

## Philosophy

- **Systems engineering, simplified.** Structure borrowed from DoD-STD-498 and traditional SRS/SDD practices, but streamlined for small projects.
- **Git is the version control.** No internal versioning of specs. The manifest tracks file hashes for freshness checking.
- **Interfaces are first-class.** Requirements, interfaces, and design are separate concerns with clear relationships.
- **Ephemeral analysis.** Impact analysis and task plans are working documents, not permanent artifacts.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/londey/syskit/refs/heads/master/install.sh | bash
```

Or download `install.sh` and run it in your project root:

```bash
cd my-project
./install.sh
```

This creates:

```
my-project/
├── CLAUDE.md
├── .claude/
│   └── commands/
│       ├── syskit-guide.md
│       ├── syskit-impact.md
│       ├── syskit-propose.md
│       ├── syskit-plan.md
│       └── syskit-implement.md
├── doc/
│   ├── requirements/
│   │   ├── req_000_template.md
│   │   ├── states_and_modes.md
│   │   └── quality_metrics.md
│   ├── interfaces/
│   │   └── int_000_template.md
│   └── design/
│       ├── unit_000_template.md
│       ├── design_decisions.md
│       └── concept_of_execution.md
└── .syskit/
    ├── AGENTS.md
    ├── manifest.md
    ├── scripts/
    │   ├── manifest.sh
    │   ├── new-req.sh
    │   ├── new-int.sh
    │   └── new-unit.sh
    ├── analysis/
    └── tasks/
```

## Usage

After installation, use the slash commands in your AI assistant:

- `/syskit-guide` — Interactive onboarding walkthrough (start here)
- `/syskit-impact <change description>` — Analyze which specs are affected by a proposed change
- `/syskit-propose` — Propose modifications to affected specs
- `/syskit-plan` — Create implementation task breakdown
- `/syskit-implement` — Execute the planned tasks

### Creating New Documents

```bash
.syskit/scripts/new-req.sh spi_interface
.syskit/scripts/new-int.sh register_map
.syskit/scripts/new-unit.sh spi_slave
```

### Updating the Manifest

```bash
.syskit/scripts/manifest.sh
```

Run this after modifying spec documents to update the hash manifest.

## Document Structure

### Requirements (`doc/requirements/`)

- `states_and_modes.md` — System operational states and transitions
- `quality_metrics.md` — Performance, reliability, maintainability requirements
- `req_NNN_<name>.md` — Individual requirements

### Interfaces (`doc/interfaces/`)

- `int_NNN_<name>.md` — Interface specifications (internal or external)

### Design (`doc/design/`)

- `design_decisions.md` — Architecture Decision Records
- `concept_of_execution.md` — Runtime behavior and data flow
- `unit_NNN_<name>.md` — Software/hardware unit descriptions

## Development

See [DEVELOPING.md](DEVELOPING.md) for information on developing syskit itself.

## License

MIT
