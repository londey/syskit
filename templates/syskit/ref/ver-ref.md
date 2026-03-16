# Ver-ref: Test-to-Verification Traceability Reference

Test files that implement a verification procedure include a `Ver-ref` comment linking back to the verification document:

```text
// Ver-ref: ver_003_watchdog.md `a1b2c3d4e5f6g7h8` 2026-03-16
```

- Filename: the verification document basename
- Hash: 16-char truncated SHA256 of the VER file content
- Date: when the test was last synced to the spec
- Comment prefix matches the test language (`//`, `#`, `--`, etc.)

## Multiple Ver-refs

A test file may have multiple Ver-ref lines if it covers multiple verifications (common for integration tests):

```text
// Ver-ref: ver_003_watchdog.md `a1b2c3d4e5f6g7h8` 2026-03-16
// Ver-ref: ver_007_timeout.md  `f8e7d6c5b4a39201` 2026-03-16
```

## Checking Test Freshness

```bash
.syskit/scripts/ver-check.sh              # full scan → .syskit/ver-status.md
.syskit/scripts/ver-check.sh VER-003      # single VER → stdout
```

Status meanings:

- ✓ current — test hash matches current VER spec
- ⚠ stale — VER spec has changed since test was last synced
- ✗ missing — Ver-ref points to a VER file that does not exist
- ○ untracked — VER lists test files but none have Ver-ref back-references

## Updating Ver-ref Hashes

After modifying a verification document, update the Ver-ref hashes:

```bash
.syskit/scripts/ver-stamp.sh VER-003      # stamp one VER
.syskit/scripts/ver-stamp.sh              # stamp all VERs
```

This reads the VER's `## Test Implementation` section, computes the current SHA256 of the VER file, and updates the hash and date in each test file's Ver-ref comment. It also warns about:

- Test files listed in ## Test Implementation that have no Ver-ref line
- Test files with Ver-ref to this VER that are not listed in ## Test Implementation (orphans)

**Important:** Do not manually edit Ver-ref hash values. Always use `ver-stamp.sh`.

## Creating New Test Files

When creating a new test file for a verification, add a placeholder Ver-ref line:

```text
// Ver-ref: ver_NNN_name.md `0000000000000000` 1970-01-01
```

Then run `ver-stamp.sh VER-NNN` to set the correct hash.

## Finding Untested Verifications

To find VER documents with method=Test that have no Ver-ref in any test file:

```bash
.syskit/scripts/trace-query.sh --untested
```
