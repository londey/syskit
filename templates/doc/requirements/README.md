# Requirements

This directory contains the system requirements specification — the authoritative record of **what** the system must do.

## Purpose

Each requirement document defines a single, testable system behavior using the condition/response pattern:

> **When** [condition], the system **SHALL/SHOULD/MAY** [behavior].

Requirements are traceable: each is allocated to design units (`UNIT-NNN`) and references interfaces (`INT-NNN`). Together they form a complete, verifiable description of system capability.

## Conventions

- **Naming:** `req_NNN_<name>.md` — 3-digit zero-padded number, lowercase, underscores
- **Create new:** `.syskit/scripts/new-req.sh <name>`
- **Cross-references:** Use `REQ-NNN` identifiers (derived from filename)
- **Hierarchy:** Use the `Parent Requirements` field for decomposition

## Framework Documents

- **quality_metrics.md** — Quality attributes, targets, and measurement methods
- **states_and_modes.md** — System operational states, modes, and transitions

## Table of Contents

<!-- TOC-START -->
*Run `.syskit/scripts/toc-update.sh` to generate.*
<!-- TOC-END -->
