# Interfaces

*Interface Design Description (IDD)*

Each interface document defines a precise contract: data formats, protocols, APIs, or signal definitions. Types:

- **Internal** — Defined by this project (register maps, packet formats, internal APIs)
- **External Standard** — Defined by an external spec (PNG, SPI, USB)
- **External Service** — Defined by an external service (REST API, cloud endpoint)

## Conventions

- **Naming:** `int_NNN_<name>.md` (children use dot notation: `int_NNN.NN_<name>.md`)
- **Create new:** `.syskit/scripts/new-int.sh <name>` (add `--parent INT-NNN` for a child)

See `.syskit/AGENTS.md` §File Numbering and §Cross-References for shared rules.

## Specification Completeness

When writing the Details section of an interface, cover the items relevant to its type:

**Hardware interfaces:**
- Signal definitions
- Timing requirements
- Electrical characteristics

**Data formats:**
- Field definitions
- Encoding
- Constraints and valid ranges

**APIs:**
- Endpoints / functions
- Parameters
- Return values
- Error conditions

## Table of Contents

<!-- TOC-START -->
*Run `.syskit/scripts/toc-update.sh` to generate.*
<!-- TOC-END -->
