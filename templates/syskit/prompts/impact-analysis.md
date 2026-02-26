# Impact Analysis — Subagent Instructions

You are analyzing the impact of a proposed change on specification documents.

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## Proposed Change

{{PROPOSED_CHANGE}}

## Instructions

1. Read ALL markdown files in these directories:
   - `doc/requirements/`
   - `doc/interfaces/`
   - `doc/design/`
   - `doc/verification/`

   Also read `ARCHITECTURE.md` from the project root (it contains manually-written sections and an auto-generated block diagram).

   Skip any files with `_000_template` in the name.

2. For each document, extract:
   - The document ID: for numbered specs, extract from the H1 heading (e.g., "REQ-001", "INT-003", "UNIT-007", "VER-002"). For framework documents (README.md, quality_metrics.md, states_and_modes.md, concept_of_execution.md, design_decisions.md, test_strategy.md) and ARCHITECTURE.md, use the filename as the identifier.
   - The document title (from the H1 heading)
   - All cross-references to other documents (REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN mentions)
   - A brief summary of what the document specifies (1-2 sentences)

3. Analyze each document against the proposed change. Categorize as:
   - **DIRECT**: The document itself describes something being changed
   - **INTERFACE**: The document defines or uses an interface affected by the change
   - **DEPENDENT**: The document depends on something being changed (via REQ/INT/UNIT references to a DIRECT or INTERFACE document)
   - **UNAFFECTED**: The document is not impacted

   When tracing dependencies:
   - If a requirement is DIRECT, check which design units have it in "Implements Requirements" (those are DEPENDENT)
   - If a requirement is DIRECT, check which interfaces it lists under "Interfaces" (those are INTERFACE)
   - If a requirement is DIRECT, check which verifications have it in "Verifies Requirements" (those are DEPENDENT)
   - If an interface is DIRECT or INTERFACE, check which units list it under "Provides" or "Consumes" (those are DEPENDENT)
   - If a design unit is DIRECT, check which requirements it implements (review for DEPENDENT impact)
   - If a design unit is DIRECT, check which verifications have it in "Verified Design Units" (those are DEPENDENT)

4. Write your complete analysis to `{{ANALYSIS_FOLDER}}/impact.md` in this format:

   ```markdown
   # Impact Analysis: <brief change summary>

   Created: <timestamp>
   Status: Pending Review

   ## Proposed Change

   <detailed description of the change>

   ## Direct Impacts

   ### <filename>
   - **ID:** <REQ/INT/UNIT/VER-NNN or filename for framework docs>
   - **Title:** <document title>
   - **Impact:** <what specifically is affected, 1-2 sentences>
   - **Action Required:** <modify/review/no change>
   - **Key References:** <cross-referenced IDs found in this document>

   ## Interface Impacts

   ### <filename>
   - **ID:** <INT-NNN>
   - **Title:** <document title>
   - **Impact:** <what specifically is affected>
   - **Consumers:** <UNIT-NNN that consume this interface>
   - **Providers:** <UNIT-NNN that provide this interface>
   - **Action Required:** <modify/review/no change>

   ## Dependent Impacts

   ### <filename>
   - **ID:** <REQ/INT/UNIT/VER-NNN or filename for framework docs>
   - **Title:** <document title>
   - **Dependency:** <what it depends on that is changing, with specific ID>
   - **Impact:** <what specifically is affected>
   - **Action Required:** <modify/review/no change>

   ## Summary

   - **Total Documents:** <n>
   - **Directly Affected:** <n>
   - **Interface Affected:** <n>
   - **Dependently Affected:** <n>
   - **Unaffected:** <n>

   ## Recommended Next Steps

   1. <first action>
   2. <second action>
   ```

   If a category has no documents, include the heading with "None." underneath.
   Do not list individual unaffected documents — the summary counts are sufficient.

5. After writing the file, return ONLY this compact summary (nothing else):

   IMPACT_SUMMARY_START
   Total: <n> documents analyzed
   Direct: <n> — <comma-separated filenames>
   Interface: <n> — <comma-separated filenames>
   Dependent: <n> — <comma-separated filenames>
   Unaffected: <n>
   Written to: {{ANALYSIS_FOLDER}}/impact.md
   IMPACT_SUMMARY_END
