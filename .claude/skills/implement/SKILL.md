---
name: implement
description: Implement a Linear ticket with the user. Research it, agree on decisions, build it, review it with subagents, then iterate on the user's feedback until they sign off.
disable-model-invocation: true
argument-hint: <ticket-id>
allowed-tools:
  - Bash(git branch --show-current)
  - Bash(wt step eval *)
---

Current branch: !`git branch --show-current`

Default branch: !`wt step eval '{{ default_branch }}'`

Implement Linear ticket $ARGUMENTS with the user. If this conversation already ran `/implement` for this ticket, go to [Rerun](#rerun).

Complexity means how hard the code is to read and change, as `docs/books/a-philosophy-of-software-design.md` defines it. It does not mean line count or the size of the diff. Prefer a larger change that leaves deeper modules and simpler interfaces.

Never commit, stage or unstage anything. Staged changes are the ones the user has approved.

## 1. Start

1. If the current branch is the default branch, stop. Ask the user to create a worktree with `wt switch --create <branch>` and run `/implement` there.
2. Fetch the ticket, its comments and its related issues from Linear.
3. Assign the ticket to the user and move it to In Progress.

## 2. Research

Read `docs/books/a-philosophy-of-software-design.md`. Then run these two searches in parallel subagents:

- The code the ticket touches, and how the codebase already solves similar problems.
- The idiomatic way to solve it with our stack: the `ash-framework` and `phoenix-framework` skills, `mix usage_rules.search_docs`, and the latest docs of the libraries involved.

For each non-trivial part, draft at least two designs and compare them by interface simplicity, information hiding and special cases.

## 3. Problem and decisions

In one message:

1. Describe the problem in a few plain sentences: what is wrong or missing today, and what done looks like.
2. List the obvious choices you made, one line each, so the user can object.
3. Ask about the technical and product decisions that aren't obvious, at most 3 at a time. For each, give the options in one sentence each, then your recommendation and why in one sentence.

Keep asking until no decision is open, then implement.

## 4. Implement

Follow CLAUDE.md, including its rules for tests and i18n. Then run `mix precommit` and fix what fails.

## 5. Review

Make sure the dev server runs the latest code. CLAUDE.md explains how to restart it. Then launch these subagents in parallel:

- `conventions-reviewer`
- `design-reviewer`
- `refactor-reviewer`
- `ui-reviewer`, only if the change affects the UI

Give each reviewer:

- a summary of the ticket
- the decisions you made with the user, and why
- the changes to review. The first time, that's all uncommitted changes (`git diff HEAD` and untracked files). On a rerun, it's only unstaged changes and untracked files. Staged changes are context only.
- the report format: one finding per item, with `file:line`, the problem, the fix, and whether it is a **clear fix** (one obvious answer that doesn't change what the user agreed on) or a **trade-off** (several valid options, or it changes behavior, UX or scope)

Then handle the findings:

- Apply the clear fixes.
- Ask the user about trade-offs, findings that contradict a decision made with the user, and reviewers who disagree with each other. Use the format from step 3.
- Drop findings you think are wrong. Say which, and why, in the hand-off.

If the fixes reshaped the code beyond local edits, run the affected reviewers once more. Then run `mix precommit` again.

## 6. Hand off

Tell the user briefly:

- what changed, by file
- how to try it: the app's URL (`WC_URL` in `.env`) and what to do there
- what the reviewers found: what you fixed, what you dropped and why
- anything still open

Then ask the user to stage what they approve and reply with their feedback.

## Rerun

When the user replies with feedback, apply it to the unstaged changes. If feedback is ambiguous or opens a new decision, ask first, using the format from step 3. Then repeat steps 4 to 6.

Repeat until the user signs off.
