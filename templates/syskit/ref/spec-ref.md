# Spec-ref: Implementation Traceability Reference

Source files that implement a design unit include a `Spec-ref` comment linking back to the unit document:

```text
// Spec-ref: unit_006_pixel_pipeline.md `a1b2c3d4e5f6g7h8` 2026-02-11
```

- Filename: the design unit document basename
- Hash: 16-char truncated SHA256 of the unit file content (same format as manifest)
- Date: when the implementation was last synced to the spec
- Comment prefix matches the source language (`//`, `//!`, `#`, `--`, etc.)

## Checking Implementation Freshness

```bash
.syskit/scripts/impl-check.sh              # full scan → .syskit/impl-status.md
.syskit/scripts/impl-check.sh UNIT-006     # single unit → stdout
```

Status meanings:

- ✓ current — implementation hash matches current spec
- ⚠ stale — spec has changed since implementation was last synced
- ✗ missing — Spec-ref points to a unit file that does not exist
- ○ untracked — unit lists source files but none have Spec-ref back-references

## Updating Spec-ref Hashes

After implementing spec changes, update the Spec-ref hashes:

```bash
.syskit/scripts/impl-stamp.sh UNIT-006
```

This reads the unit's `## Implementation` section, computes the current SHA256 of the unit file, and updates the hash and date in each source file's Spec-ref comment. It also warns about:

- Source files listed in ## Implementation that have no Spec-ref line
- Source files with Spec-ref to this unit that are not listed in ## Implementation (orphans)

**Important:** Do not manually edit Spec-ref hash values or write scripts to update them. Always use `impl-stamp.sh`.

## Creating New Implementation Files

When creating a new implementation file, add a placeholder Spec-ref line:

```text
// Spec-ref: unit_NNN_name.md `0000000000000000` 1970-01-01
```

Then run `impl-stamp.sh UNIT-NNN` to set the correct hash.
