# Refine Changes (Scoped) — Subagent Instructions

You are drafting and applying proposed specification changes for a specific scope of documents, based on a completed impact analysis.

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## Proposed Change

{{PROPOSED_CHANGE}}

## Scope

You are refining ONLY the following documents:

{{SCOPE_FILTER}}

Scope type: {{SCOPE_NAME}}

## Instructions

1. Read the impact analysis from: `{{ANALYSIS_FOLDER}}/impact.md`

2. Read ONLY the documents listed in your scope (above) from the `doc/` directories. Do NOT read or modify documents outside your scope.

3. If other refinement files exist in `{{ANALYSIS_FOLDER}}/` (e.g., `refine_requirements.md` from a previous iteration), read them to understand what changes have already been made. Your changes should be consistent with previously approved refinements.

4. For each scoped document, **edit the file directly** with the proposed changes:
   - Make the specific modifications needed to address the proposed change
   - Ensure all cross-references (REQ-NNN, INT-NNN, UNIT-NNN) remain consistent
   - For requirement documents, ensure every requirement uses the condition/response pattern: "When [condition], the system SHALL [observable behavior]."
   - When referencing documents outside your scope that are also affected (per impact.md), note that they will be refined in a later iteration — flag these in the Cross-Scope Notes section.

5. While editing, validate each requirement you modify or create:
   - **Format:** Must use condition/response pattern. If it lacks a trigger condition, add one.
   - **Appropriate Level:** If it specifies data layout, register fields, byte encoding, packet structure, or wire protocol details, flag this — that detail belongs in an interface document.
   - **Singular:** If it addresses multiple capabilities, split it into separate requirements.
   - **Verifiable:** The condition must define a clear test setup and the behavior a clear pass criterion.

6. Write a refinement summary to `{{ANALYSIS_FOLDER}}/refine_{{SCOPE_NAME}}.md` in this format:

   ```markdown
   # Refinement: {{SCOPE_NAME}}

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

   ### Cross-Scope Dependencies

   - <references to documents in other scopes that may need updating>

   ---

   (repeat for each scoped document)

   ## Quality Warnings

   <list any requirement quality issues found, or "None.">

   ## Cross-Scope Notes

   <list any changes that may affect documents in other scopes, to be addressed in subsequent refine iterations or a re-run of impact analysis>
   ```

7. After editing all scoped documents and writing the summary, return ONLY this compact response (nothing else):

   REFINE_SUMMARY_START
   Scope: {{SCOPE_NAME}}
   Documents edited: <n>
   Files: <comma-separated filenames>
   Quality warnings: <n> (<brief list or "None">)
   Cross-scope notes: <n> (<brief list or "None">)
   Summary written to: {{ANALYSIS_FOLDER}}/refine_{{SCOPE_NAME}}.md
   REFINE_SUMMARY_END
