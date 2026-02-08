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

- Use SHALL for mandatory requirements
- Use SHOULD for recommended requirements  
- Use MAY for optional requirements
- Each requirement should be testable/verifiable
- Reference interfaces with `INT-NNN`
- Allocate to design units with `UNIT-NNN`

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
3. Write `snapshot.md` with SHA256 of each referenced document
4. Write `proposed_changes.md` with specific modifications to each affected document
5. Wait for human approval before modifying `doc/` files

### Planning Implementation

After spec changes are approved and applied:

1. Create task folder: `.syskit/tasks/<date>_<change_name>/`
2. Write `plan.md` with implementation strategy
3. Write individual `task_NNN_<name>.md` files for each discrete task
4. Include `snapshot.md` referencing current doc hashes
5. Tasks should be small enough to implement and verify independently

### Implementing

1. Work through tasks in order
2. After each task, verify against relevant requirements
3. Update design unit documents if implementation details change
4. Run `.syskit/scripts/manifest.sh` after doc changes

## Freshness Checking

Analysis and task files include SHA256 snapshots of referenced documents.

When loading previous analysis or tasks:

1. Compare snapshot hashes against current manifest
2. Flag any documents that have changed:
   - ✓ unchanged — analysis still valid for this document
   - ⚠ modified — review if changes affect analysis
   - ✗ deleted — analysis references removed document
3. If critical documents changed, recommend re-running analysis

## File Numbering

When creating new documents:

- Find highest existing number in that category
- Use next number with 3-digit padding: `001`, `002`, etc.
- Use `_` separator, lowercase, no spaces in names
- Examples: `req_001_system_overview.md`, `int_003_register_map.md`

Or use the helper scripts:

```bash
.syskit/scripts/new-req.sh <name>
.syskit/scripts/new-int.sh <name>  
.syskit/scripts/new-unit.sh <name>
```

## Cross-References

Use consistent identifiers when referencing between documents:

- `REQ-001` — Requirement 001
- `REQ-001.3` — Third sub-requirement of requirement 001
- `INT-005` — Interface 005
- `UNIT-012` — Design unit 012

These identifiers are derived from filenames: `req_001_foo.md` → `REQ-001`
