# Document Format Reference

## Document Style Principles

These apply to all document types (requirements, interfaces, design units):

1. **Documents are the current truth, not a changelog.** Write what the system *is*, not how it evolved. History belongs in git commits and their messages. After editing a document, re-read it — it should stand alone as the definitive reference without any narrative about previous versions.

2. **No version numbers on internal documents.** Internal interfaces, requirements, and design units are versioned by git. Do not add "Version:", "v2", or revision history sections. External interfaces may reference the version of the external specification they describe (e.g., "SPI Mode 0", "PNG 1.2").

3. **Keep rationale sections brief.** Rationale explains *why* a decision was made, not *what* the whole system does. Reference other `doc/` files by ID (REQ-NNN, INT-NNN, UNIT-NNN) rather than re-describing their content.

4. **Cross-reference, don't duplicate.** If information is defined in another document, reference it by ID. Each fact should have one authoritative location.

5. **Be concise.** Documents should be scannable. Prefer tables and lists over prose. Omit filler phrases and obvious context.

## Requirements (`req_NNN_<name>.md`)

Requirements state WHAT the system must do, not HOW.

See `.syskit/ref/requirement-format.md` for the required format, quality criteria, and level-of-abstraction guidance.

## Interfaces (`int_NNN_<name>.md`)

Interfaces define contracts. They may be:

- **Internal:** Defined by this project (register maps, packet formats, internal APIs)
- **External:** Defined elsewhere (PNG format, SPI protocol, USB spec)

For external interfaces, document:

- The external specification and version
- How this system uses/constrains it
- What subset of features are supported

For internal interfaces, the document IS the specification.

## Design Units (`unit_NNN_<name>.md`)

Design units describe HOW a piece of the system works.

- Reference requirements being implemented with `REQ-NNN`
- Reference interfaces being implemented/consumed with `INT-NNN`
- Document internal interfaces to other units
- Link to implementation files in `src/`

## Verification (`ver_NNN_<name>.md`)

Verification documents describe HOW a requirement is verified.

- Reference requirements being verified with `REQ-NNN`
- Reference design units being exercised with `UNIT-NNN`
- Link to test implementation files
- Define pass/fail criteria
