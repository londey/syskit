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
5. Ensure Spec-ref traceability for every design unit you implement:
   a. For each UNIT-NNN referenced by this task, read the unit document's `## Implementation` section to find the list of source files.
   b. For every file listed there — whether you created it or it already existed — verify it contains a Spec-ref comment for that unit. If it does not, add a placeholder:
      ```
      // Spec-ref: unit_NNN_name.md `0000000000000000` 1970-01-01
      ```
      Use the comment prefix appropriate for the file's language (`//` for C/Verilog/SystemVerilog, `#` for Python/Bash/Makefile, `--` for VHDL/SQL/Lua, etc.). Place it near the top of the file, after any file-level header comment or license block.
   c. If you created or modified a file that implements a unit but that file is NOT listed in the unit's `## Implementation` section, add it there in the format: `` - `path/to/file`: <brief description> ``
   d. If you used a different filename than what the `## Implementation` section lists, update the `## Implementation` entry to match the actual filename.
   e. Do not edit Spec-ref hash values manually — `impl-stamp.sh` will set them after you finish.

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
