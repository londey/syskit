# Refine Proposed Changes — Subagent Instructions

You are refining previously proposed specification changes based on the user's review feedback.

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## User Feedback

{{FEEDBACK}}

## Affected Files

The following documents may need modification based on the feedback:

{{AFFECTED_FILES}}

## Instructions

1. Read the impact analysis summary from: `{{ANALYSIS_FOLDER}}/impact.md` — read only the `## Summary` section (last ~15 lines) for context.

2. Read the change summary from: `{{ANALYSIS_FOLDER}}/proposed_changes.md` — read the `## Change Summary` table to understand what was originally proposed.

3. Read each file listed in the affected files above from the `doc/` directories (or from the project root for `ARCHITECTURE.md`). These files already contain the proposed changes (uncommitted).

4. Run `git diff -- <file>` for each affected file to see what was changed by the original proposal. This helps you understand the baseline and avoid undoing correct changes.

5. Analyze the user's feedback against the current state of the documents. Determine what specific edits are needed to address the feedback.

6. For each document that needs changes, **edit the file directly**:
   - Make the specific modifications needed to address the user's feedback
   - Preserve correct changes from the original proposal — only modify what the feedback asks for
   - Ensure all cross-references (REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN) remain consistent
   - For verification documents, ensure "Verifies Requirements" and "Verified Design Units" sections reflect the current requirements and design units. Update the Procedure and Expected Results sections if the verified behavior changed.
   - For requirement documents, ensure every requirement uses the condition/response pattern: "When [condition], the system SHALL [observable behavior]."
   - **Document style** (critical): Write what the system *is now* — no changelog language, no version numbers. See `.syskit/ref/document-formats.md` for full style rules.

7. While editing, validate each requirement against `.syskit/ref/requirement-format.md` §Quality Criteria. In particular: condition/response pattern, singular scope, no data-layout details (move those to INT), verifiable trigger/outcome.

8. If the feedback implies changes to documents NOT in your affected files list (e.g., the user's feedback about one document creates a consistency issue with another), note this in the cross-impact section of your summary but do NOT modify documents outside your list.

9. After editing all affected documents, return ONLY this compact response (nothing else):

   REFINE_SUMMARY_START
   Feedback: <one-line summary of the feedback addressed>
   Documents examined: <n>
   Documents edited: <n>
   Files edited: <comma-separated filenames>
   Changes: <one-line per edited file: "filename — brief description of what changed">
   Quality warnings: <n> (<brief list or "None">)
   Cross-impact notes: <any consistency issues with documents outside the affected set, or "None">
   REFINE_SUMMARY_END
