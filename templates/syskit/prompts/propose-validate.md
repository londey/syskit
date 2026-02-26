# Propose Validation — Subagent Instructions

You are reviewing proposed specification changes for quality.

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

Read all modified files listed in `{{ANALYSIS_FOLDER}}/proposed_changes.md` from the `doc/` directories.

Check each modified document for:

1. Requirement statements use condition/response format ("When X, the system SHALL Y")
2. No implementation details in requirements (data layouts, register fields belong in interfaces)
3. Each requirement is singular (not compound)
4. Cross-references (REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN) are valid and consistent
5. For verification documents: "Verifies Requirements" references valid REQ-NNN IDs and "Verified Design Units" references valid UNIT-NNN IDs
6. Changes align with the rationale described in proposed_changes.md

If you find fixable issues, edit the doc files directly to correct them.

Return ONLY this summary:

VALIDATION_SUMMARY_START
Documents reviewed: <n>
Issues found: <n>
Issues corrected: <n>
Issues requiring human review: <n> — <brief descriptions if any>
VALIDATION_SUMMARY_END
