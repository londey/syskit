# Cross-Reference Reference

## Identifiers

- `REQ-001` — Requirement 001 (top-level)
- `REQ-001.03` — Requirement 001, child 03
- `INT-005` — Interface 005 (top-level)
- `INT-005.01` — Interface 005, child 01
- `UNIT-012` — Design unit 012 (top-level)
- `UNIT-012.03` — Design unit 012, child 03
- `VER-007` — Verification 007 (top-level)
- `VER-007.02` — Verification 007, child 02

Identifiers are derived from filenames: `req_001_foo.md` → `REQ-001`, `req_001.03_bar.md` → `REQ-001.03`, `int_005.01_uart.md` → `INT-005.01`, `unit_012.03_pid.md` → `UNIT-012.03`, `ver_007_motor_test.md` → `VER-007`, `ver_007.02_edge_cases.md` → `VER-007.02`

## Hierarchical Numbering

All document types support two-level hierarchy using dot-notation. Child documents use `NNN.NN` to show their parent:

- Top-level: `req_004_motor_control.md` → `REQ-004`
- Child: `req_004.01_voltage_levels.md` → `REQ-004.01`
- Top-level: `int_005_peripheral_bus.md` → `INT-005`
- Child: `int_005.01_uart_registers.md` → `INT-005.01`
- Top-level: `unit_012_control_loop.md` → `UNIT-012`
- Child: `unit_012.03_pid_controller.md` → `UNIT-012.03`
- Top-level: `ver_007_motor_test.md` → `VER-007`
- Child: `ver_007.02_edge_cases.md` → `VER-007.02`

Top-level IDs use 3-digit padding (`NNN`). Children use 2-digit padding (`.NN`). Hierarchy is limited to two levels.

## Reference Direction Rules

References flow in one direction only — from more concrete documents toward more abstract ones:

- **INT** — References no other syskit documents
- **REQ** — May reference INT only (via `## Interfaces`)
- **UNIT** — May reference REQ and INT (via `## Implements Requirements`, `### Provides`, `### Consumes`)
- **VER** — May reference REQ, UNIT, and INT (via `## Verifies Requirements`, `## Verified Design Units`)

This means each document only declares its own forward references. There are no back-reference sections to maintain, so changes to one document do not cascade into others.

## Cross-Reference Validation

Run the validation tool to check for issues:

```bash
.syskit/scripts/trace-sync.sh
```

This reports:
- **Broken references** — IDs that point to nonexistent documents
- **Direction violations** — References that violate the hierarchy (e.g., a REQ referencing a UNIT)
- **Orphans** — Documents not referenced by anything (excluding VER, which sits at the top)

## Reverse Lookups

To find what references a given document, use the query tool:

```bash
.syskit/scripts/trace-query.sh REQ-001        # What implements/verifies this?
.syskit/scripts/trace-query.sh INT-003        # Who provides/consumes/references this?
.syskit/scripts/trace-query.sh UNIT-005       # What verifies this unit?
.syskit/scripts/trace-query.sh --coverage     # Full traceability matrix
.syskit/scripts/trace-query.sh --unimplemented # REQs with no UNIT implementing them
.syskit/scripts/trace-query.sh --unverified    # REQs with no VER verifying them
```
