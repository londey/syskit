# Cross-Reference Reference

## Identifiers

- `REQ-001` — Requirement 001 (top-level)
- `REQ-001.03` — Requirement 001.03 (child of REQ-001)
- `INT-005` — Interface 005
- `UNIT-012` — Design unit 012

Identifiers are derived from filenames: `req_001_foo.md` → `REQ-001`, `req_001.03_bar.md` → `REQ-001.03`

## Hierarchical Requirement Numbering

Child requirements use dot-notation to show their parent relationship:

- Top-level: `req_004_motor_control.md` → `REQ-004`
- Child: `req_004.01_voltage_levels.md` → `REQ-004.01`
- Grandchild: `req_004.01.03_overvoltage_protection.md` → `REQ-004.01.03`

Top-level IDs use 3-digit padding (`NNN`). Each child level uses 2-digit padding (`.NN`).

## Bidirectional Links

The following links must be maintained bidirectionally:

- REQ "Allocated To" ↔ UNIT "Implements Requirements"
- REQ "Interfaces" ↔ INT "Referenced By"
- UNIT "Provides" ↔ INT "Parties Provider"
- UNIT "Consumes" ↔ INT "Parties Consumer"

## Cross-Reference Sync

After modifying cross-references, run the sync tool:

```bash
.syskit/scripts/trace-sync.sh          # check mode — report issues
.syskit/scripts/trace-sync.sh --fix    # fix mode — add missing back-references
```

This tool verifies bidirectional links and reports broken references (IDs with no matching file) and orphan documents.

**Important:** Do not write custom scripts for traceability updates. Use `trace-sync.sh`.
