# Propose Changes (Chunk) — Subagent Instructions

You are drafting and applying proposed specification changes for a subset of affected documents.

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## Proposed Change

{{PROPOSED_CHANGE}}

## Your Assigned Documents

{{ASSIGNED_FILES}}

## Instructions

1. Read the impact analysis from: `{{ANALYSIS_FOLDER}}/impact.md`

2. Read ONLY the documents assigned to you (listed above) from the `doc/` directories.

3. For each assigned document, **edit the file directly** with the proposed changes:
   - Make the specific modifications needed to address the proposed change
   - Ensure all cross-references (REQ-NNN, INT-NNN, UNIT-NNN) remain consistent
   - For requirement documents, ensure every requirement uses the condition/response pattern: "When [condition], the system SHALL [observable behavior]."
   - **Document style rules** (critical):
     - Write what the system *is now*, not how it changed. No changelog-style language ("previously", "was changed to", "updated from"). The git diff is the changelog.
     - Do not add version numbers, revision history, or "Version:" fields to internal documents. Git is the version control.
     - Keep rationale sections brief — explain *why*, don't re-describe the system. Reference other docs by ID (REQ-NNN, INT-NNN, UNIT-NNN) instead of duplicating their content.
     - After editing, re-read the document — it should stand alone as the definitive reference.

4. While editing, validate each requirement you modify or create:
   - **Format:** Must use condition/response pattern. If it lacks a trigger condition, add one.
   - **Appropriate Level:** If it specifies data layout, register fields, byte encoding, packet structure, or wire protocol details, flag this — that detail belongs in an interface document.
   - **Singular:** If it addresses multiple capabilities, split it into separate requirements.
   - **Verifiable:** The condition must define a clear test setup and the behavior a clear pass criterion.

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
