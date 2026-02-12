# syskit — AI Assistant Instructions

This project uses syskit for specification-driven development.

**New to syskit?** Run `/syskit-guide` for an interactive walkthrough.

## Document Locations

All persistent engineering documents live under `doc/`:

- `doc/requirements/` — What the system must do
- `doc/interfaces/` — Contracts between components and with external systems
- `doc/design/` — How the system accomplishes requirements

Working documents live under `.syskit/`:

- `.syskit/analysis/` — Impact analysis results (ephemeral)
- `.syskit/tasks/` — Implementation task plans (ephemeral)
- `.syskit/manifest.md` — SHA256 hashes of all doc files

## Document Types

### Requirements (`req_NNN_<name>.md`)

Requirements state WHAT the system must do, not HOW.

**Required format** — every requirement must use the condition/response pattern:

> **When** [condition/trigger], the system **SHALL/SHOULD/MAY** [observable behavior/response].

- **SHALL** = mandatory, **SHOULD** = recommended, **MAY** = optional
- Reference interfaces with `INT-NNN`
- Allocate to design units with `UNIT-NNN`

**Requirement quality criteria** — each requirement must be:

- **Necessary:** Removing it would cause a system deficiency
- **Singular:** Addresses one thing only — split compound requirements
- **Correct:** Accurately describes the needed capability
- **Unambiguous:** Has only one possible interpretation — no vague terms
- **Feasible:** Can be implemented within known constraints
- **Appropriate to Level:** Describes capabilities/behaviors, not implementation mechanisms
- **Complete:** Contains all information needed to implement and verify
- **Conforming:** Uses the project's standard template and condition/response format
- **Verifiable:** The condition defines the test setup; the behavior defines the pass criterion

**Level of abstraction** — if a requirement describes data layout, register fields, byte encoding, packet structure, memory maps, or wire protocols, that detail belongs in an interface document (`INT-NNN`), not a requirement. The requirement should reference the interface.

- Wrong: "The system SHALL have an error counter" *(no condition, not testable)*
- Wrong: "The system SHALL transmit a 16-byte header with bytes 0-3 as a big-endian sequence number" *(implementation detail, belongs in an interface)*
- Right: "When the system receives a malformed message, the system SHALL discard the message and increment the error counter"
- Right: "When the system transmits a message, the system SHALL include a unique sequence number per INT-005"

### Interfaces (`int_NNN_<name>.md`)

Interfaces define contracts. They may be:

- **Internal:** Defined by this project (register maps, packet formats, internal APIs)
- **External:** Defined elsewhere (PNG format, SPI protocol, USB spec)

For external interfaces, document:

- The external specification and version
- How this system uses/constrains it
- What subset of features are supported

For internal interfaces, the document IS the specification.

### Design Units (`unit_NNN_<name>.md`)

Design units describe HOW a piece of the system works.

- Reference requirements being implemented with `REQ-NNN`
- Reference interfaces being implemented/consumed with `INT-NNN`
- Document internal interfaces to other units
- Link to implementation files in `src/`

## Workflows

### Before Making Changes

Always run impact analysis first:

1. Load all documents from `doc/` into context
2. Analyze which documents are affected by the proposed change
3. Categorize as DIRECT, DEPENDENT, or INTERFACE impact
4. Check manifest for any documents modified since last analysis

### Proposing Changes

1. Create analysis folder: `.syskit/analysis/<date>_<change_name>/`
2. Write `impact.md` listing affected documents with rationale
3. Generate `snapshot.md` by running: `.syskit/scripts/manifest-snapshot.sh <analysis-folder>`
4. Write `proposed_changes.md` with specific modifications to each affected document
5. Wait for human approval before modifying `doc/` files

### Planning Implementation

After spec changes are approved and applied:

1. Create task folder: `.syskit/tasks/<date>_<change_name>/`
2. Write `plan.md` with implementation strategy
3. Write individual `task_NNN_<name>.md` files for each discrete task
4. Generate `snapshot.md` by running: `.syskit/scripts/manifest-snapshot.sh <task-folder>`
5. Tasks should be small enough to implement and verify independently

### Implementing

1. Work through tasks in order
2. After each task, verify against relevant requirements
3. Update design unit documents if implementation details change
4. Run `.syskit/scripts/trace-sync.sh` to verify cross-references are consistent
5. Run `.syskit/scripts/impl-stamp.sh UNIT-NNN` for each modified unit to update Spec-ref hashes
6. Run `.syskit/scripts/impl-check.sh` to verify implementation freshness
7. Run `.syskit/scripts/manifest.sh` after doc changes

## Freshness Checking

Analysis and task files include SHA256 snapshots of referenced documents.

When loading previous analysis or tasks, run the check script:

```bash
.syskit/scripts/manifest-check.sh <path-to-snapshot.md>
```

The script compares snapshot hashes against current file state and reports:

- ✓ unchanged — analysis still valid for this document
- ⚠ modified — review if changes affect analysis
- ✗ deleted — analysis references removed document

Exit code 0 means all documents are fresh; exit code 1 means some have changed.

If critical documents changed, recommend re-running analysis.

## File Numbering

When creating new documents:

- Find highest existing number in that category
- Use next number with 3-digit padding: `001`, `002`, etc.
- Use `_` separator, lowercase, no spaces in names
- Examples: `req_001_system_overview.md`, `int_003_register_map.md`

### Hierarchical Requirement Numbering

Child requirements use dot-notation to show their parent relationship:

- Top-level: `req_004_motor_control.md` → `REQ-004`
- Child: `req_004.01_voltage_levels.md` → `REQ-004.01`
- Grandchild: `req_004.01.03_overvoltage_protection.md` → `REQ-004.01.03`

Top-level IDs use 3-digit padding (`NNN`). Each child level uses 2-digit padding (`.NN`).

This numbering makes the requirement hierarchy visible from the ID alone and groups
sibling requirements in directory listings.

### Helper Scripts

```bash
.syskit/scripts/new-req.sh <name>                        # top-level requirement
.syskit/scripts/new-req.sh --parent REQ-004 <name>       # child of REQ-004
.syskit/scripts/new-req.sh --parent REQ-004.01 <name>    # grandchild
.syskit/scripts/new-int.sh <name>
.syskit/scripts/new-unit.sh <name>
```

## Cross-References

Use consistent identifiers when referencing between documents:

- `REQ-001` — Requirement 001 (top-level)
- `REQ-001.03` — Requirement 001.03 (child of REQ-001)
- `INT-005` — Interface 005
- `UNIT-012` — Design unit 012

These identifiers are derived from filenames: `req_001_foo.md` → `REQ-001`, `req_001.03_bar.md` → `REQ-001.03`

Requirements use hierarchical numbering to make decomposition visible. The parent
relationship is encoded in the ID itself — `REQ-004.15` is a child of `REQ-004`.
Each requirement still gets its own file, and the `Parent Requirements` field provides
an explicit back-reference for traceability verification.

### Cross-Reference Sync

After modifying cross-references, run the sync tool to check consistency:

```bash
.syskit/scripts/trace-sync.sh          # check mode — report issues
.syskit/scripts/trace-sync.sh --fix    # fix mode — add missing back-references
```

This tool verifies bidirectional links between documents:

- REQ "Allocated To" ↔ UNIT "Implements Requirements"
- REQ "Interfaces" ↔ INT "Referenced By"
- UNIT "Provides" ↔ INT "Parties Provider"
- UNIT "Consumes" ↔ INT "Parties Consumer"

It also reports broken references (IDs with no matching file) and orphan documents.

**Important:** Do not write custom Python scripts or ad-hoc tools for traceability updates.
Use `trace-sync.sh` — it requires only standard bash tools.

### Spec-ref: Implementation Traceability

Source files that implement a design unit include a `Spec-ref` comment linking back to the unit document:

```text
// Spec-ref: unit_006_pixel_pipeline.md `a1b2c3d4e5f6g7h8` 2026-02-11
```

- Filename: the design unit document basename
- Hash: 16-char truncated SHA256 of the unit file content (same format as manifest)
- Date: when the implementation was last synced to the spec
- Comment prefix matches the source language (`//`, `//!`, `#`, `--`, etc.)

#### Checking Implementation Freshness

```bash
.syskit/scripts/impl-check.sh              # full scan → .syskit/impl-status.md
.syskit/scripts/impl-check.sh UNIT-006     # single unit → stdout
```

Status meanings:

- ✓ current — implementation hash matches current spec
- ⚠ stale — spec has changed since implementation was last synced
- ✗ missing — Spec-ref points to a unit file that does not exist
- ○ untracked — unit lists source files but none have Spec-ref back-references

#### Updating Spec-ref Hashes

After implementing spec changes, update the Spec-ref hashes:

```bash
.syskit/scripts/impl-stamp.sh UNIT-006
```

This reads the unit's `## Implementation` section, computes the current SHA256 of the unit file, and updates the hash and date in each source file's Spec-ref comment. It also warns about:

- Source files listed in ## Implementation that have no Spec-ref line
- Source files with Spec-ref to this unit that are not listed in ## Implementation (orphans)

**Important:** Do not manually edit Spec-ref hash values or write scripts to update them.
Always use `impl-stamp.sh` — it requires only standard bash tools.

When creating a new implementation file, add a placeholder Spec-ref line:

```text
// Spec-ref: unit_NNN_name.md `0000000000000000` 1970-01-01
```

Then run `impl-stamp.sh UNIT-NNN` to set the correct hash.
