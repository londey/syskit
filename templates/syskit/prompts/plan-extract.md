# Plan Extraction — Subagent Instructions

You are extracting implementation scope from approved specification changes.

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## Instructions

1. Read the change summary from: `{{ANALYSIS_FOLDER}}/proposed_changes.md`

2. Run `git diff doc/ ARCHITECTURE.md` to see the exact specification changes that were applied.

3. Read all design unit documents (`doc/design/unit_*.md`) to understand implementation structure. Focus especially on:
   - The `## Implementation` section (lists source files)
   - The `## Implements Requirements` section (links to REQ-NNN)
   - The `## Provides` and `## Consumes` sections (links to INT-NNN)

4. Read verification documents (`doc/verification/ver_*.md`) that cover affected requirements or design units. Focus especially on:
   - The `## Verifies Requirements` section (links to REQ-NNN)
   - The `## Verified Design Units` section (links to UNIT-NNN)
   - The `## Test Implementation` section (lists test source files)

5. If the changes affected framework documents (quality_metrics.md, states_and_modes.md, concept_of_execution.md, design_decisions.md, test_strategy.md, README.md files) or `ARCHITECTURE.md`, read those files to understand what changed and whether implementation tasks are needed.

6. For each specification change, identify:
   - Which source files need modification (from design unit Implementation sections)
   - Which test files need modification or creation (from design unit and verification Test Implementation sections)
   - Which verification documents need updating if requirements or design unit behavior changed
   - Dependencies between changes (what must be done first)
   - How to verify the change was implemented correctly

7. Create the task folder: `{{TASK_FOLDER}}`

8. Write `plan.md` to the task folder:

   ```markdown
   # Implementation Plan: <change name>

   Based on: ../../.syskit/analysis/<folder>/proposed_changes.md
   Created: <timestamp>
   Status: In Progress

   ## Overview

   <Brief description of what is being implemented>

   ## Specification Changes Applied

   | Document | Change Type | Summary |
   |----------|-------------|---------|
   | <doc> | Modified | <summary> |

   ## Implementation Strategy

   <High-level approach to implementing these changes>

   ## Task Sequence

   | # | Task | Dependencies | Est. Effort |
   |---|------|--------------|-------------|
   | 1 | <task name> | None | <small/medium/large> |
   | 2 | <task name> | Task 1 | <effort> |

   ## Verification Approach

   <How we will verify the implementation meets the specifications>

   ## Risks and Considerations

   - <risk or consideration>
   ```

9. Write individual task files `task_NNN_<name>.md` to the task folder:

   ```markdown
   # Task NNN: <task name>

   Status: Pending
   Dependencies: <list or "None">
   Specification References: <REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN>

   ## Objective

   <What this task accomplishes>

   ## Files to Modify

   - `<filepath>`: <what changes>

   ## Files to Create

   - `<filepath>`: <purpose>

   ## Implementation Steps

   1. <step>
   2. <step>
   3. <step>

   ## Verification

   - [ ] <verification criterion>
   - [ ] <verification criterion>

   ## Notes

   <Any additional context or considerations>
   ```

10. After writing all files, return ONLY this compact summary (nothing else):

   PLAN_SUMMARY_START
   Task folder: <path to task folder>
   Tasks created: <n>
   Task sequence:
   1. <task name> (deps: None)
   2. <task name> (deps: Task 1)
   ...
   Source files to modify: <n>
   Source files to create: <n>
   Risks: <n>
   PLAN_SUMMARY_END
