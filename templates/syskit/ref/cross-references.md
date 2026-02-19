# Cross-Reference Reference

## Identifiers

- `REQ-001` — Requirement 001 (top-level)
- `REQ-001.03` — Requirement 001, child 03
- `INT-005` — Interface 005 (top-level)
- `INT-005.01` — Interface 005, child 01
- `UNIT-012` — Design unit 012 (top-level)
- `UNIT-012.03` — Design unit 012, child 03

Identifiers are derived from filenames: `req_001_foo.md` → `REQ-001`, `req_001.03_bar.md` → `REQ-001.03`, `int_005.01_uart.md` → `INT-005.01`, `unit_012.03_pid.md` → `UNIT-012.03`

## Hierarchical Numbering

All document types support two-level hierarchy using dot-notation. Child documents use `NNN.NN` to show their parent:

- Top-level: `req_004_motor_control.md` → `REQ-004`
- Child: `req_004.01_voltage_levels.md` → `REQ-004.01`
- Top-level: `int_005_peripheral_bus.md` → `INT-005`
- Child: `int_005.01_uart_registers.md` → `INT-005.01`
- Top-level: `unit_012_control_loop.md` → `UNIT-012`
- Child: `unit_012.03_pid_controller.md` → `UNIT-012.03`

Top-level IDs use 3-digit padding (`NNN`). Children use 2-digit padding (`.NN`). Hierarchy is limited to two levels.

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
