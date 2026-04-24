# Requirements

*Software Requirements Specification (SRS)*

Each requirement document defines a single, testable system behavior:

> **When** [condition], the system **SHALL/SHOULD/MAY** [behavior].

Requirements reference the interfaces they depend on (`INT-NNN`); design units reference the requirements they implement.

## Conventions

- **Naming:** `req_NNN_<name>.md` (children use dot notation: `req_NNN.NN_<name>.md`)
- **Create new:** `.syskit/scripts/new-req.sh <name>` (add `--parent REQ-NNN` for a child)

See `.syskit/AGENTS.md` §File Numbering and §Cross-References for shared rules.

## Framework Documents

- **quality_metrics.md** — Quality attributes, targets, and measurement methods
- **states_and_modes.md** — System operational states, modes, and transitions

## Table of Contents

<!-- TOC-START -->
*Run `.syskit/scripts/toc-update.sh` to generate.*
<!-- TOC-END -->
