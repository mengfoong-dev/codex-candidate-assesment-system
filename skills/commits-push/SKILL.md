---
name: commits-push
description: Safely identify task-relevant changes, confirm ambiguous staging and push-target choices, commit only approved files to the current local branch, and push to the selected upstream. Use when Codex is asked to commit, commit and push, publish changes, or synchronize a Git branch.
---

# Commit and Push

Review the worktree before acting, filter and sort changed files by relevance to the user's task, and preserve unrelated work. Ask before changing Git state when scope, staging, stashes, conflicts, or the remote target is unclear; otherwise commit selected changes locally and push the chosen upstream without rewriting history.

## Guardrails

- Read repository instructions first and follow any session-logging requirement.
- Never use git reset --hard, git clean, git checkout --, force-push, or history rewriting unless the user explicitly requests that exact operation.
- Never stage or discard unrelated work, secrets, generated files, conflict files, or another agent's changes.
- Never resolve conflicts, apply/drop stashes, amend, merge, or rebase silently when intent is ambiguous.
- Do not create an empty commit. If the requested changes are already committed, report that commit.
- Push only after verifying the local commit and the actual push output.

## Workflow

### 1. Inspect, filter, and sort

Run read-only inspection from the repository root:

    git rev-parse --show-toplevel
    git status --short --branch
    git status --porcelain=v2
    git branch --show-current
    git branch -vv
    git remote -v
    git stash list
    git diff --stat
    git diff --name-status
    git diff --cached --stat
    git diff --cached --name-status
    git log -5 --oneline --decorate

Classify every changed path before selecting anything:

- Direct task files: named by the user or clearly implementing the requested task.
- Supporting files: tests, configuration, documentation, migrations, and assets required by direct files.
- Bookkeeping/generated files: session logs, build output, incidental lockfiles, and generated artifacts.
- Unrelated files: changes without a demonstrated relationship to the task.
- Conflict files: any U, UU, AA, DD, or equivalent unmerged status.

Sort output as direct task files, supporting files, bookkeeping/generated files, then unrelated files; sort alphabetically within each group. Inspect relevant diffs, not just filenames. Treat conflict files as a hard stop.

### 2. Ask when a decision is not obvious

Proceed without asking only when the task scope, staged/unstaged choice, untracked-file choice, stash handling, and push remote/branch are all clear.

If anything is unclear, stop after inspection and ask one concise question covering the unresolved choices. Use structured user input when available; otherwise ask plainly. Specifically clarify which dirty files to include, whether to preserve or change the index, whether to include untracked files, whether to leave/inspect/apply/drop a named stash, and whether to push the configured upstream, origin/main, origin/staging, or another explicit target.

Do not infer permission to include unrelated dirty files merely because the user says "commit everything." If that conflicts with repository guardrails or there are conflicts, clarify.

### 3. Stage explicitly

After scope is confirmed, stage explicit paths:

    git add -- path/to/approved-file path/to/approved-directory

Do not use git add -A or git add . when unrelated or ambiguous changes exist. Preserve unrelated files already staged unless the user directs otherwise. Never stage an unmerged path.

Verify the exact index before committing:

    git diff --cached --name-status
    git diff --cached --stat
    git diff --cached --check

Run the smallest relevant validation and report exactly what ran.

### 4. Commit locally

Use a concise imperative message, then verify:

    git commit -m "<imperative task summary>"
    git show --stat --oneline --decorate HEAD
    git status --short --branch

If the selected changes already belong to an existing commit, do not amend or duplicate it. If a hook or changing index causes failure, stop and reassess instead of forcing the commit.

### 5. Resolve and verify the push target

Prefer the configured upstream when the user did not specify another target:

    git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}"

If no upstream exists or multiple targets are plausible, ask before pushing. Common targets are origin/<current-branch>, origin/main, and origin/staging; do not assume main when the branch or request indicates otherwise.

Fetch only when needed to inspect remote state:

    git fetch <remote>
    git status --short --branch

If the target has commits absent locally, stop and ask whether to merge or rebase; do not do either automatically. Never force-push. For a confirmed target, push explicitly:

    git push <remote> HEAD:<remote-branch>

Verify afterward:

    git status --short --branch
    git rev-parse HEAD
    git ls-remote --heads <remote> <remote-branch>

### 6. Report

State the commit hash/message, exact committed paths, validation results, push target/result (or why pushing was not performed), and remaining dirty or conflicted paths.

## Repository-specific guardrails

- Never stage docs/hackathon/codex-usage/sessions.csv with implementation or documentation changes; leave session bookkeeping for its own explicit commit.
- Never stage .superpowers/ or docs/hackathon/codex-usage/active-session.json with task changes.
- Preserve ignored personal context such as CLAUDE.local.md.
- Treat a conflicted docs/hackathon/codex-usage/sessions.csv as a blocker requiring user direction.
