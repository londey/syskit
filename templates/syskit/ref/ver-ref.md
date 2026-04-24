# Ver-ref: Test-to-Verification Traceability Reference

Test files that implement a verification procedure include a `Ver-ref` comment linking back to the verification document:

```text
// Ver-ref: ver_003_watchdog.md
```

- Filename: the verification document basename
- Comment prefix matches the test language (`//`, `#`, `--`, etc.)

Ver-refs are pure navigational pointers. They do not track VER content or sync dates.

## Multiple Ver-refs

A test file may have multiple Ver-ref lines if it covers multiple verifications (common for integration tests):

```text
// Ver-ref: ver_003_watchdog.md
// Ver-ref: ver_007_timeout.md
```

## Checking Test Consistency

```bash
.syskit/scripts/ver-check.sh              # full scan → .syskit/ver-status.md
.syskit/scripts/ver-check.sh VER-003      # single VER → stdout
```

Status meanings:

- ✗ missing — Ver-ref points to a VER file that does not exist
- ⚠ orphan — test file has a Ver-ref not listed in the VER's `## Test Implementation`
- ○ untracked — VER lists test files but none have Ver-ref back-references

## Creating New Test Files

When creating a new test file for a verification, add a Ver-ref line:

```text
// Ver-ref: ver_NNN_name.md
```

Use the comment prefix appropriate for the test file's language. Also ensure the file is listed in the VER document's `## Test Implementation` section.

## Finding Untested Verifications

To find VER documents with method=Test that have no Ver-ref in any test file:

```bash
.syskit/scripts/trace-query.sh --untested
```
