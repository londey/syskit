# Propose Changes (Single) — Subagent Instructions

You are drafting and applying proposed specification changes based on a completed impact analysis.

## Proposed Change

{{PROPOSED_CHANGE}}

## Instructions

1. Read the impact analysis from: `{{ANALYSIS_FOLDER}}/impact.md`

2. Read each document listed as affected (DIRECT, INTERFACE, or DEPENDENT with Action Required of "modify" or "review"). Read them from the `doc/` directories.

3. For each affected document, **edit the file directly** with the proposed changes:
   - Make the specific modifications needed to address the proposed change
   - Ensure all cross-references (REQ-NNN, INT-NNN, UNIT-NNN) remain consistent
   - For requirement documents, ensure every requirement uses the condition/response pattern: "When [condition], the system SHALL [observable behavior]."

4. While editing, validate each requirement you modify or create:
   - **Format:** Must use condition/response pattern. If it lacks a trigger condition, add one.
   - **Appropriate Level:** If it specifies data layout, register fields, byte encoding, packet structure, or wire protocol details, flag this — that detail belongs in an interface document.
   - **Singular:** If it addresses multiple capabilities, split it into separate requirements.
   - **Verifiable:** The condition must define a clear test setup and the behavior a clear pass criterion.

5. Write a change summary to `{{ANALYSIS_FOLDER}}/proposed_changes.md` in this format:

   ```markdown
   # Proposed Changes: <change name>

   Based on: impact.md
   Created: <timestamp>
   Status: Pending Approval

   ## Change Summary

   | Document | Type | Change Description |
   |----------|------|-------------------|
   | <filename> | Modify | <brief description> |

   ## Document: <filename>

   ### Rationale

   <why this change is needed>

   ### Changes Made

   <brief description of what was modified — the actual diff is in git>

   ### Ripple Effects

   - <any effects on other documents>

   ---

   (repeat for each affected document)

   ## Quality Warnings

   <list any requirement quality issues found, or "None.">
   ```

6. After editing all documents and writing the summary, return ONLY this compact response (nothing else):

   PROPOSE_SUMMARY_START
   Documents edited: <n>
   Files: <comma-separated filenames>
   Quality warnings: <n> (<brief list or "None">)
   Summary written to: {{ANALYSIS_FOLDER}}/proposed_changes.md
   PROPOSE_SUMMARY_END
