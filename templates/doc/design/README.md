# Design

*Software Design Description (SDD)*

Each design unit describes a cohesive piece of the system: its purpose, the requirements it satisfies, the interfaces it provides and consumes, and its internal behavior. Design units link to source files and test files, enabling full traceability.

## Conventions

- **Naming:** `unit_NNN_<name>.md` (children use dot notation: `unit_NNN.NN_<name>.md`)
- **Create new:** `.syskit/scripts/new-unit.sh <name>` (add `--parent UNIT-NNN` for a child)
- **Traceability:** Source files link back via `Spec-ref` comments. Run `.syskit/scripts/impl-check.sh` to verify bidirectional consistency between `## Implementation` and source-file Spec-refs.

See `.syskit/AGENTS.md` §File Numbering and §Cross-References for shared rules.

## Framework Documents

- **concept_of_execution.md** — System runtime behavior, startup, data flow, and event handling
- **design_decisions.md** — Broadly-affecting design choices (framework selection, architectural patterns, major trade-offs). See ADR Format below.

## ADR Format

When adding a new decision to `design_decisions.md`, use this skeleton:

````markdown
## DD-NNN: <Title>

**Status:** Proposed | Accepted | Superseded by DD-XXX

### Context

<What is the issue or question that needs a decision?>

### Decision

<What is the decision that was made?>

### Rationale

<Why was this decision made? What alternatives were considered?>

### Consequences

<What are the implications of this decision?>
````

## Table of Contents

<!-- TOC-START -->
*Run `.syskit/scripts/toc-update.sh` to generate.*
<!-- TOC-END -->
