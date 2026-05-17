# Work-a-Task Workflow

Run this workflow once per scheduled invocation. Pick **one** task, triage or complete it, commit, and stop. Never do more than one task per run.

---

## Step 1: Pre-flight

Check working tree:
```
git status
```
If there are any uncommitted changes, **abort** — print "Aborting: working tree is not clean." and stop entirely.

Pull latest:
```
git pull origin main
```

---

## Step 2: Pick the task

Read `tasks/README.md`. Find the `### Active` section. Take the **literal first item** in that flat list — this is your task for this run.

If there are no items under `### Active`, exit cleanly with "No active tasks." and stop (no commit).

Read the task file in full.

---

## Step 3: Triage

Choose exactly one branch. Reason explicitly before deciding.

### Branch A — Looks already done

The described problem or missing feature already exists in the code or docs. To check: read the relevant scripts, grep for the described symbol or behavior, look at what the code actually does today.

If already done:
1. Append to the task file:
   ```
   ## Resolution

   Looks complete on inspection — [specific evidence: what you checked and what you found].
   ```
2. `git mv tasks/active/NNN-slug.md tasks/completed/NNN-slug.md`
3. Remove the task's line from `tasks/README.md`.
4. Append the task's line (with category tag) to `tasks/completed/README.md`.
5. Commit: `chore: close task NNN as already-done`
6. `git push origin main`
7. **Stop.**

### Branch B — Not enough information

The task is too ambiguous to act on: it raises a design question with no clear answer, has no concrete acceptance criteria, needs a stakeholder decision, or is marked as a question/discussion.

If not enough information:
1. Append to the task file:
   ```
   ## Triage

   Moved to review — [explain exactly what's missing or what decision needs to be made before this can be acted on].
   ```
2. `git mv tasks/active/NNN-slug.md tasks/review/NNN-slug.md`
3. Remove the task's line from `tasks/README.md`.
4. Commit: `chore: move task NNN to review — needs decision`
5. `git push origin main`
6. **Stop.**

### Branch C — Too big for one run

The task describes multiple independent concerns, would require separate design decisions for each, or cannot be summarized in one implementation paragraph. If you're in doubt, a task that touches more than ~3 files across different systems is likely too big.

If too big:
1. Identify the logical sub-tasks (aim for 2–5; each should be completable in one run).
2. Find the highest existing task number: scan filenames across `tasks/active/`, `tasks/review/`, `tasks/completed/`, and `tasks/post-release/`. Use `NNN+1`, `NNN+2`, etc. for new files.
3. Create `tasks/active/NNN-slug.md` for each sub-task with:
   - A clear title
   - `**Category:**` matching the parent (unless obviously different)
   - `**Source:** Split from task [parent NNN — parent slug]`
   - A scoped, concrete description
4. Insert each sub-task line into `tasks/README.md` under `### Active`, at the parent's original position (highest-priority sub-task first), with the parent's category tag.
5. Update the parent task file:
   ```
   ## Resolution

   Task was too large for one run. Split into sub-tasks: NNN — slug, NNN — slug[, ...].
   ```
6. `git mv tasks/active/NNN-slug.md tasks/completed/NNN-slug.md`
7. Remove parent line from active README; append parent line to `tasks/completed/README.md`.
8. Commit: `chore: split task NNN into subtasks NNN, NNN[, NNN]`
9. `git push origin main`
10. **Stop.**

### Branch D — Executable

The task is clear, scoped, and you can describe the implementation in one paragraph. Continue to Step 4.

---

## Step 4: Execute

Implement the task.

**Scope rules:**
- Only touch what the task directly describes.
- If you find a related problem that is not this task, create a follow-up task (new `NNN-slug.md` in `tasks/active/`, slotted into `tasks/README.md` immediately after the current task's position with the same category tag). Note the follow-up in the resolution. Do not fix it now.
- If your changes affect symbols, paths, or behaviors referenced in `docs/`, update those docs. Grep the doc files for changed names and fix them. The `docs/specs/2026-05-17-task-routine-design.md` drift-audit section is a good model for what "relevant" means.

**Project context:**
- GDScript 2.0 / Godot 4.5
- `agents.md` is the authoritative project entry point — read it before touching any GDScript
- Logging: `GameManager.log(LOG_PREFIX, …)` — never `print()`
- Tests: `tests/run_tests.ps1`
- Strict static typing preferred

---

## Step 5: Verify

If you changed any `.gd` files, run:
```
tests/run_tests.ps1
```
Tests must exit 0 (green). If they fail:
- If you can fix the failure within the task's scope, fix it and re-run.
- If you cannot fix it in scope: revert all code changes (`git restore .`), then treat as **Branch B** with triage note: `"tests blocked: [failure summary] — reverted, needs investigation"`. Move task to review, commit, push, stop.

Doc-only or text-only changes: skip this step.

---

## Step 6: Bookkeep

1. Append to the task file:
   ```
   ## Resolution

   [1–3 sentences describing what changed and why.]
   Files touched: [comma-separated list]
   Follow-ups created: [NNN — slug, or "none"]
   ```
2. `git mv tasks/active/NNN-slug.md tasks/completed/NNN-slug.md`
3. Remove the task's line from `tasks/README.md`.
4. Append the task's line (with category tag) to `tasks/completed/README.md`.
5. If follow-ups were created, insert their lines into `tasks/README.md` under `### Active`, immediately after the current task's old position.

---

## Step 7: Commit and push

Stage all changed files by name and commit:
```
git commit -m "<type>: <one-line summary> (task NNN)"
git push origin main
```

Commit type conventions (from `docs/dev_guide/commit_conventions.md`):
- `fix:` — bug fix
- `feat:` — new behavior
- `chore:` — refactors, renames, internal cleanup
- `docs:` — documentation only
- `balance:` — tuning / numbers

Done.
