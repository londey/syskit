# Plan Extraction — Subagent Instructions

You are extracting implementation scope from approved specification changes.

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## Instructions

1. Read the change summary from: `{{ANALYSIS_FOLDER}}/proposed_changes.md`

2. Run `git diff doc/` to see the exact specification changes that were applied.

3. Read all design unit documents (`doc/design/unit_*.md`) to understand implementation structure. Focus especially on:
   - The `## Implementation` section (lists source files)
   - The `## Implements Requirements` section (links to REQ-NNN)
   - The `## Provides` and `## Consumes` sections (links to INT-NNN)

4. For each specification change, identify:
   - Which source files need modification (from design unit Implementation sections)
   - Which test files need modification or creation
   - Dependencies between changes (what must be done first)
   - How to verify the change was implemented correctly

5. Create the task folder: `{{TASK_FOLDER}}`

6. Write `plan.md` to the task folder:

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

7. Write individual task files `task_NNN_<name>.md` to the task folder:

   ```markdown
   # Task NNN: <task name>

   Status: Pending
   Dependencies: <list or "None">
   Specification References: <REQ-NNN, INT-NNN, UNIT-NNN>

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

8. After writing all files, return ONLY this compact summary (nothing else):

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
