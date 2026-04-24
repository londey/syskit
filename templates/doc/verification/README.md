# Verification

*Software Verification Description (SVD)*

Each verification document describes a test or analysis procedure that demonstrates a requirement is satisfied. Methods:

- **Test** — Verified by executing a test procedure with defined pass/fail criteria
- **Analysis** — Verified by technical evaluation (calculation, simulation, modeling)
- **Inspection** — Verified by examination of design artifacts
- **Demonstration** — Verified by operating the system under specified conditions

## Conventions

- **Naming:** `ver_NNN_<name>.md` (children use dot notation: `ver_NNN.NN_<name>.md`)
- **Create new:** `.syskit/scripts/new-ver.sh <name>` (add `--parent VER-NNN` for a child)
- **Traceability:** Test files link back via `Ver-ref` comments. Run `.syskit/scripts/ver-check.sh` to verify bidirectional consistency between `## Test Implementation` and test-file Ver-refs.

See `.syskit/AGENTS.md` §File Numbering and §Cross-References for shared rules.

## Framework Documents

- **test_strategy.md** — Cross-cutting test strategy: frameworks, tools, coverage goals, and approaches

## Table of Contents

<!-- TOC-START -->
*Run `.syskit/scripts/toc-update.sh` to generate.*
<!-- TOC-END -->
