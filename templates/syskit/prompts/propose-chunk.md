# Propose Changes (Chunk) — Subagent Instructions

You are drafting and applying proposed specification changes for a subset of affected documents.

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## Proposed Change

{{PROPOSED_CHANGE}}

## Your Assigned Documents

{{ASSIGNED_FILES}}

## Instructions

1. Read the impact analysis from: `{{ANALYSIS_FOLDER}}/impact.md`

2. Read ONLY the documents assigned to you (listed above) from the `doc/` directories, or from the project root for `ARCHITECTURE.md`.

3. For each assigned document, **edit the file directly** with the proposed changes:
   - Make the specific modifications needed to address the proposed change
   - Ensure all cross-references (REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN) remain consistent
   - For verification documents, ensure "Verifies Requirements" and "Verified Design Units" sections reflect the current requirements and design units. Update the Procedure and Expected Results sections if the verified behavior changed.
   - For requirement documents, ensure every requirement uses the condition/response pattern: "When [condition], the system SHALL [observable behavior]."
   - **Document style** (critical): Write what the system *is now* — no changelog language, no version numbers. See `.syskit/ref/document-formats.md` for full style rules.

4. While editing, validate each requirement against `.syskit/ref/requirement-format.md` §Quality Criteria. In particular: condition/response pattern, singular scope, no data-layout details (move those to INT), verifiable trigger/outcome.

5. Write a chunk summary to `{{ANALYSIS_FOLDER}}/chunk_{{CHUNK_NUMBER}}.md` in this format:

   ```markdown
   ## Document: <filename>

   ### Rationale

   <why this change is needed>

   ### Changes Made

   <brief description of what was modified — the actual diff is in git>

   ### Ripple Effects

   - <any effects on other documents>

   ---

   (repeat for each assigned document)
   ```

6. After editing all assigned documents and writing the chunk summary, return ONLY this compact response (nothing else):

   CHUNK_SUMMARY_START
   Chunk: {{CHUNK_NUMBER}}
   Documents edited: <n>
   Files: <comma-separated filenames>
   Quality warnings: <n> (<brief list or "None">)
   Written to: {{ANALYSIS_FOLDER}}/chunk_{{CHUNK_NUMBER}}.md
   CHUNK_SUMMARY_END
