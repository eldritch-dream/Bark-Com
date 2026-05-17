# Task Routine — Design

A scheduled routine that picks the top task from `tasks/README.md`, triages or completes it, and updates bookkeeping. The routine prompt itself is short: "Read `.agent/workflows/work-a-task.md` and follow it." The workflow file holds all the logic and lives in source control.

## Goals

- Keep the active task list moving without manual triage every day.
- Constrain blast radius: one task per run, committed to `main`, easy to revert.
- Self-healing bookkeeping: READMEs stay in sync with file locations automatically.

## Non-goals

- Parallel runs. Routines fire sequentially on a schedule.
- Branch/PR workflow. We commit to `main` for now; revisit if the audit gap hurts.
- Cross-task planning. Each run sees only the top task.

## Architecture

Two new files plus a one-time restructure of an existing file.

### 1. `.agent/workflows/work-a-task.md` (new)

The workflow. Sections in order:

1. **Pre-flight** — clean working tree required (abort otherwise); `git pull` main.
2. **Self-heal** — if `tasks/completed/README.md` doesn't exist, create it with the existing entry for task 153.
3. **Pick the task** — read `tasks/README.md`, take the literal first item under `### Active`.
4. **Triage** — exactly one branch fires:
   - **Looks already done** → append `## Resolution` ("Looks complete on inspection — <evidence>"), move file to `completed/`, update both READMEs, commit, exit.
   - **Not enough info** (ambiguous, design question, no concrete acceptance criteria) → append `## Triage` note explaining what's missing, move to `review/`, remove from active README, commit, exit.
   - **Too big for one run** (touches multiple independent concerns) → create new `NNN-slug.md` files for the pieces using next available number, slot them into active README at parent's position with parent's category by default, archive parent to `completed/` with "split into NNN, NNN, NNN" note, update both READMEs, commit, exit.
   - **Executable as-is** → continue.
5. **Execute** — stay scoped; anything tangential becomes a follow-up task slotted into the active README (same category-by-default rule); update any docs that reference touched symbols/paths (mirror the agents.md drift-audit pattern).
6. **Verify** — if any `.gd` file changed, run `tests/run_tests.ps1`; require green. Doc/text-only changes skip tests.
7. **Bookkeep**:
   - Append `## Resolution` to the task file: summary, files touched, follow-ups created.
   - `git mv tasks/active/NNN-slug.md tasks/completed/NNN-slug.md`.
   - Remove the task's line from `tasks/README.md`.
   - Append the task's line to `tasks/completed/README.md` (completion order = append to bottom).
   - If follow-ups were created, insert their lines into the active README at appropriate priority/category.
8. **Commit** — `<type>: <one-line summary> (task NNN)`. Push to `main`.

### 2. `tasks/completed/README.md` (new)

Index for completed tasks, append-only by completion date. Same line format as the active README so visually consistent.

### 3. `tasks/README.md` (restructure)

Convert the `### Active` section from category-grouped to flat, priority-ordered, with inline category tags:

```
### Active
- [001 — Action cam ignores camera rotation (q/e)](active/001-action-cam-camera-rotation.md) *(Bug)*
- [011 — Actions should stay clicked to allow multi-action chains](active/011-actions-stay-clicked.md) *(UX)*
...
```

Initial flat order = current section concatenation (Bugs → UX → Balance → Refactor → Performance → Tooling), preserving existing within-section order. Reorder freely afterward.

`### Review` section stays as-is (no priority semantics there).

## Edge cases the workflow must handle

- **Dirty working tree** → abort with a console note, no commit.
- **No active tasks** → exit cleanly, no commit.
- **Tests fail and can't be fixed in scope** → revert code changes, move task to `review/` with `## Triage` note `tests blocked: <failure summary>`, commit just the README move + triage note.
- **Self-conflict on README** (shouldn't happen with sequential runs but defensive): re-read README before each edit, don't cache.

## What the routine prompt looks like

```
Read .agent/workflows/work-a-task.md and follow it exactly. Pick the top
active task, triage or complete it per the workflow, and commit to main.
```

That's it. All logic lives in the workflow file so you can edit behavior without touching the routine.

## Open questions / future iteration

- **Audit gap from no-PR**: if direct-to-main commits surface a bad pattern, switch to branch+PR with a one-open-PR guard.
- **Decomposition aggressiveness**: routine splits big tasks autonomously. If the splits are consistently wrong, switch to "move to review with a decomposition note" instead.
- **Follow-up priority placement**: defaults to "right under the parent task's old position." Revisit if this clusters too much.
