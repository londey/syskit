# Implement Task — Subagent Instructions

You are implementing a single task from a syskit implementation plan.

**Important:** Do NOT read `.syskit/AGENTS.md` — your instructions are self-contained in this prompt.

## Your Assignment

- **Task file:** `{{TASK_FILE}}`
- **Task folder:** `{{TASK_FOLDER}}`

## Instructions

### 1. Read the Task

Read your task file at `{{TASK_FILE}}`. Extract:

- The objective
- Files to modify and files to create
- Implementation steps
- Verification criteria
- Specification references (REQ-NNN, INT-NNN, UNIT-NNN, VER-NNN)

### 2. Read Referenced Files

Read all files listed in:

- **"Files to Modify"** — the source files you will change
- **"Specification References"** — the spec documents that define the required behavior

Read each file from disk. Understand what the specification requires and what the current implementation looks like.

### 3. Implement

Follow the task's implementation steps:

1. Make the changes described in the task
2. Edit files directly — do not write to a staging folder
3. Ensure changes align with the referenced specifications
4. If the task references VER-NNN documents and implementation changes affect verified behavior, update the verification document's Procedure and Expected Results sections to match
5. When creating new source files that implement a design unit, add a placeholder Spec-ref comment:
   ```
   // Spec-ref: unit_NNN_name.md `0000000000000000` 1970-01-01
   ```
   (The hash will be updated by `impl-stamp.sh` after you finish.)

### 4. Verify

Work through the task's verification checklist:

1. For each verification criterion, confirm it is met
2. If a criterion cannot be verified, note why
3. Run any specified tests or build commands

### 5. Update Task Status

Edit the task file to update its status:

```markdown
Status: Complete
Completed: {{TIMESTAMP}}
```

Add a completion summary at the end of the task file:

```markdown
## Completion Notes

<What was actually done, any deviations from plan>

## Verification Results

- [x] <criterion> — <result>
- [x] <criterion> — <result>
```

### 6. Return Summary

After completing all steps, return ONLY this compact response (nothing else):

```
IMPLEMENT_SUMMARY_START
Task: <number> — <name>
Files modified: <n> — <comma-separated paths>
Files created: <n> — <comma-separated paths>
Verification: <passed>/<total> criteria passed
Failed criteria: <list any failures, or "None">
Issues: <any issues encountered, or "None">
IMPLEMENT_SUMMARY_END
```
