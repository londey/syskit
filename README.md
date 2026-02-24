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
curl -fsSL https://raw.githubusercontent.com/londey/syskit/refs/heads/master/install_syskit.sh | bash
```

Or download `install_syskit.sh` and run it in your project root:

```bash
cd my-project
./install_syskit.sh
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
│       ├── syskit-refine.md
│       ├── syskit-plan.md
│       └── syskit-implement.md
├── doc/
│   ├── requirements/
│   │   ├── README.md
│   │   ├── req_000_template.md
│   │   ├── states_and_modes.md
│   │   └── quality_metrics.md
│   ├── interfaces/
│   │   ├── README.md
│   │   └── int_000_template.md
│   ├── design/
│   │   ├── README.md
│   │   ├── unit_000_template.md
│   │   ├── design_decisions.md
│   │   └── concept_of_execution.md
│   └── verification/
│       ├── README.md
│       ├── ver_000_template.md
│       └── test_strategy.md
└── .syskit/
    ├── AGENTS.md
    ├── manifest.md
    ├── scripts/
    │   ├── manifest.sh
    │   ├── manifest-snapshot.sh
    │   ├── manifest-check.sh
    │   ├── new-req.sh
    │   ├── new-int.sh
    │   ├── new-unit.sh
    │   ├── new-ver.sh
    │   ├── find-task.sh
    │   ├── assemble-chunks.sh
    │   ├── toc-update.sh
    │   ├── trace-sync.sh
    │   ├── impl-stamp.sh
    │   └── impl-check.sh
    ├── prompts/
    │   └── (subagent prompt templates)
    ├── ref/
    │   └── (reference format specifications)
    ├── analysis/
    └── tasks/
```

## Usage

After installation, use the slash commands in your AI assistant:

- `/syskit-guide [system description]` — Interactive onboarding walkthrough (start here)
- `/syskit-impact <change description>` — Analyze which specs are affected by a proposed change
- `/syskit-propose` — Propose modifications to all affected specs at once
- `/syskit-refine --scope <requirements|interfaces|design>` — Propose changes to one document type at a time (iterative alternative to propose)
- `/syskit-plan` — Create implementation task breakdown from approved spec changes
- `/syskit-implement [task number]` — Execute the planned tasks

**Important:** Start a fresh conversation for each command. syskit persists all state to disk so work is never lost between conversations.

### Change Workflow

```
/syskit-impact "add CAN bus support"
      ↓
/syskit-propose          (all at once)
   — or —
/syskit-refine --scope requirements
/syskit-refine --scope interfaces
/syskit-refine --scope design
      ↓
/syskit-plan
      ↓
/syskit-implement
/syskit-implement
...
```

For large changes affecting many documents, use `/syskit-refine` to review one document type at a time. After approving a scope, run `/syskit-impact --incremental` to re-analyze with the approved changes before proceeding to the next scope.

### Creating New Documents

```bash
# Top-level documents
.syskit/scripts/new-req.sh spi_interface
.syskit/scripts/new-int.sh register_map
.syskit/scripts/new-unit.sh spi_slave
.syskit/scripts/new-ver.sh framebuffer_approval

# Child documents (dot-notation hierarchy: REQ-001.01, INT-002.01, UNIT-003.01, VER-001.01)
.syskit/scripts/new-req.sh --parent REQ-001 voltage_levels
.syskit/scripts/new-int.sh --parent INT-002 uart_registers
.syskit/scripts/new-unit.sh --parent UNIT-003 pid_controller
.syskit/scripts/new-ver.sh --parent VER-001 edge_cases
```

### Updating the Manifest

```bash
.syskit/scripts/manifest.sh
```

Run this after modifying spec documents to update the hash manifest. The manifest enables freshness checking—syskit detects when specs change between workflow steps.

### Verifying Implementation Consistency

```bash
# Check that cross-references between documents are consistent
.syskit/scripts/trace-sync.sh

# Update Spec-ref hashes after implementing a design unit
.syskit/scripts/impl-stamp.sh UNIT-NNN

# Check implementation freshness across all units
.syskit/scripts/impl-check.sh
```

## Document Structure

### Requirements (`doc/requirements/`)

- `states_and_modes.md` — System operational states and transitions
- `quality_metrics.md` — Performance, reliability, maintainability requirements
- `req_NNN_<name>.md` — Individual requirements (referenced as `REQ-NNN`)
- `req_NNN.NN_<name>.md` — Child requirements (referenced as `REQ-NNN.NN`)

Requirements use condition/response format: "When [condition], the system SHALL [observable behavior]."

### Interfaces (`doc/interfaces/`)

- `int_NNN_<name>.md` — Interface specifications, internal or external (referenced as `INT-NNN`)
- `int_NNN.NN_<name>.md` — Child interfaces (referenced as `INT-NNN.NN`)

Data layouts, register maps, protocol encodings, and field definitions belong here—not in requirements.

### Design (`doc/design/`)

- `design_decisions.md` — Architecture Decision Records
- `concept_of_execution.md` — Runtime behavior and data flow
- `unit_NNN_<name>.md` — Software/hardware unit descriptions (referenced as `UNIT-NNN`)
- `unit_NNN.NN_<name>.md` — Child units (referenced as `UNIT-NNN.NN`)

### Verification (`doc/verification/`)

- `test_strategy.md` — Cross-cutting test strategy: frameworks, tools, coverage goals, and approaches
- `ver_NNN_<name>.md` — Verification procedures (referenced as `VER-NNN`)
- `ver_NNN.NN_<name>.md` — Child verifications (referenced as `VER-NNN.NN`)

### Cross-References

Documents link to each other using `REQ-NNN`, `INT-NNN`, `UNIT-NNN`, and `VER-NNN` identifiers to create a traceability web:

- Requirements → interfaces they constrain, design units that implement them, verifications that prove them
- Design units → requirements they satisfy, interfaces they provide or consume
- Verifications → requirements they verify, design units they exercise

## Development

See [DEVELOPING.md](DEVELOPING.md) for information on developing syskit itself.

## License

MIT
