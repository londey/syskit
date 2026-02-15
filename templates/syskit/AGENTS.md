# syskit — AI Assistant Instructions

This project uses syskit for specification-driven development.

**New to syskit?** Run `/syskit-guide` for an interactive walkthrough.

## Document Locations

All persistent engineering documents live under `doc/`:

- `doc/requirements/` — What the system must do
- `doc/interfaces/` — Contracts between components and with external systems
- `doc/design/` — How the system accomplishes requirements

Working documents live under `.syskit/`:

- `.syskit/analysis/` — Impact analysis results (ephemeral)
- `.syskit/tasks/` — Implementation task plans (ephemeral)
- `.syskit/manifest.md` — SHA256 hashes of all doc files

Reference material for subagents:

- `.syskit/ref/` — Detailed format specs (requirement quality, cross-references, Spec-ref)
- `.syskit/prompts/` — Subagent prompt templates

## Document Types

- **Requirements** (`req_NNN_<name>.md`) — WHAT the system must do. Use condition/response format.
- **Interfaces** (`int_NNN_<name>.md`) — Contracts between components and external systems.
- **Design Units** (`unit_NNN_<name>.md`) — HOW the system works. Links to requirements and interfaces.

For detailed format specifications, see `.syskit/ref/document-formats.md`.

## Workflows

### Before Making Changes

Always run impact analysis first:

1. Read the manifest to get the current document inventory
2. Delegate document reading and analysis to a subagent — subagent writes results to disk and returns only a brief summary
3. Validate the subagent's summary counts against the manifest
4. Check manifest for any documents modified since last analysis

### Proposing Changes

1. Ensure `doc/` has no uncommitted changes (clean git status required)
2. Create analysis folder: `.syskit/analysis/<date>_<change_name>/`
3. Delegate change drafting to subagent(s) — subagents read impact.md from disk, edit `doc/` files directly, and write a lightweight summary to `proposed_changes.md`
4. Generate `snapshot.md` by running: `.syskit/scripts/manifest-snapshot.sh <analysis-folder>`
5. User reviews changes via `git diff doc/` and approves, revises, or rejects

### Planning Implementation

After spec changes are approved:

1. Delegate scope extraction and task creation to a subagent — subagent reads proposed_changes.md and `git diff`, writes plan.md and task files to disk
2. Generate `snapshot.md` by running: `.syskit/scripts/manifest-snapshot.sh <task-folder>`
3. Tasks should be small enough to implement and verify independently

### Implementing

1. Delegate implementation to a subagent — subagent reads the task file and all referenced files, makes changes, verifies, returns a summary
2. After each task, run post-implementation scripts to verify consistency
3. Run `.syskit/scripts/trace-sync.sh` to verify cross-references are consistent
4. Run `.syskit/scripts/impl-stamp.sh UNIT-NNN` for each modified unit to update Spec-ref hashes
5. Run `.syskit/scripts/impl-check.sh` to verify implementation freshness
6. After doc changes, run `.syskit/scripts/manifest.sh` to update the manifest

### Context Budget Management

The workflow commands use subagents to keep document content out of the main context window. Follow these rules to prevent context exhaustion:

1. **Subagents write to disk, return only summaries** — A subagent's final message becomes a tool result in the main context. Keep return messages under 1KB. Write detailed output to files in `.syskit/analysis/` or `.syskit/tasks/`.

2. **Subagents read large files from disk** — Never paste file content larger than 2KB into a subagent prompt. Instead, give the subagent the file path and let it read the file itself.

3. **Chunk large change sets** — When more than 8 documents are affected, use multiple subagents each handling a subset. Assemble results with `.syskit/scripts/assemble-chunks.sh`.

4. **Validate via summaries, not content** — Verify subagent work by checking counts and file lists in the returned summary. Do not read large output files into the main context for review.

5. **Edit doc files directly** — Subagents edit `doc/` files in place. The user reviews via `git diff`. This eliminates the largest context consumer (full proposed content for every affected file).

6. **One command per conversation** — Each syskit command persists all state to disk. Start a fresh conversation for each command to avoid context accumulation.

## Freshness Checking

Analysis and task files include SHA256 snapshots of referenced documents.

When loading previous analysis or tasks, run the check script:

```bash
.syskit/scripts/manifest-check.sh <path-to-snapshot.md>
```

Exit code 0 means all documents are fresh; exit code 1 means some have changed.

## File Numbering

When creating new documents:

- Find highest existing number in that category
- Use next number with 3-digit padding: `001`, `002`, etc.
- Use `_` separator, lowercase, no spaces in names

Helper scripts:

```bash
.syskit/scripts/new-req.sh <name>
.syskit/scripts/new-req.sh --parent REQ-004 <name>
.syskit/scripts/new-int.sh <name>
.syskit/scripts/new-unit.sh <name>
```

## Cross-References

Use `REQ-NNN`, `INT-NNN`, `UNIT-NNN` identifiers when referencing between documents.

For detailed cross-reference rules and the sync tool, see `.syskit/ref/cross-references.md`.

For Spec-ref implementation traceability, see `.syskit/ref/spec-ref.md`.
