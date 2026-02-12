# Requirements

This directory contains the system requirements specification — the authoritative record of **what** the system must do.

## Purpose

Each requirement document defines a single, testable system behavior using the condition/response pattern:

> **When** [condition], the system **SHALL/SHOULD/MAY** [behavior].

Requirements are traceable: each is allocated to design units (`UNIT-NNN`) and references interfaces (`INT-NNN`). Together they form a complete, verifiable description of system capability.

## Conventions

- **Naming:** `req_NNN_<name>.md` — 3-digit zero-padded number, lowercase, underscores
- **Child requirements:** `req_NNN.NN_<name>.md` — dot-notation encodes parent (e.g., `req_004.01_voltage_levels.md`)
- **Create new:** `.syskit/scripts/new-req.sh <name>` or `.syskit/scripts/new-req.sh --parent REQ-NNN <name>`
- **Cross-references:** Use `REQ-NNN` or `REQ-NNN.NN` identifiers (derived from filename)
- **Hierarchy:** Parent relationship is visible in the ID; `Parent Requirements` field provides explicit back-reference

## Framework Documents

- **quality_metrics.md** — Quality attributes, targets, and measurement methods
- **states_and_modes.md** — System operational states, modes, and transitions

## Table of Contents

<!-- TOC-START -->
*Run `.syskit/scripts/toc-update.sh` to generate.*
<!-- TOC-END -->
