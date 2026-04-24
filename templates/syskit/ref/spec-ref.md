# Spec-ref: Implementation Traceability Reference

Source files that implement a design unit include a `Spec-ref` comment linking back to the unit document:

```text
// Spec-ref: unit_006_pixel_pipeline.md
```

- Filename: the design unit document basename
- Comment prefix matches the source language (`//`, `//!`, `#`, `--`, etc.)

Spec-refs are pure navigational pointers. They do not track spec content or sync dates.

## Checking Implementation Consistency

```bash
.syskit/scripts/impl-check.sh              # full scan → .syskit/impl-status.md
.syskit/scripts/impl-check.sh UNIT-006     # single unit → stdout
```

Status meanings:

- ✗ missing — Spec-ref points to a unit file that does not exist
- ⚠ orphan — source file has a Spec-ref not listed in the unit's `## Implementation`
- ○ untracked — unit lists source files but none have Spec-ref back-references

## Creating New Implementation Files

When creating a new implementation file, add a Spec-ref line for the unit it implements:

```text
// Spec-ref: unit_NNN_name.md
```

Use the comment prefix appropriate for the file's language. Place it near the top of the file, after any file-level header or license block. Also ensure the file is listed in the unit document's `## Implementation` section.
