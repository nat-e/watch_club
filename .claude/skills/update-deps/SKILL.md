---
name: update-deps
description: Review a Renovate pull request that updates dependencies. Reads the changelogs between the old and new versions, finds the code that must change and the cleanups the new versions allow, and reports before the PR is merged.
argument-hint: <pr-number>
allowed-tools:
  - Bash(gh pr list *)
  - Bash(gh pr view *)
  - Bash(gh pr diff *)
  - Bash(gh pr checks *)
  - Bash(mix hex.package *)
---

Review Renovate pull request $ARGUMENTS. If no number is given, list the open ones with `gh pr list --app renovate` and ask which one to review.

## 1. List the updates

Read the PR's description and diff with `gh pr view` and `gh pr diff`. List every dependency it bumps, with the old and new version. Besides mix packages, Renovate updates npm packages, Erlang, Elixir and Biome in mise, the Dockerfile and GitHub Actions.

## 2. Read the changelogs

For each update, read every changelog entry between the two versions:

- Mix packages: `mix hex.package fetch <package> <version> --unpack --output <dir>`, with a temporary folder outside the repo, gives the new version's `CHANGELOG.md`. When the changelog is vague, `mix hex.package diff <package> <old>..<new>` shows the code that changed.
- Other dependencies: the release notes in the PR description, or the project's releases.

Note breaking changes, deprecations, behavior changes, and new features or APIs.

## 3. Check our code

For each change you noted, search the codebase for the code it affects:

- what must change: breaking changes, deprecated calls, changed behavior our code relies on
- what we can simplify: code that works around a missing feature, or that reimplements something the new version provides

The PR doesn't regenerate the usage rules. If a new version ships them (a `usage-rules.md` file or a `usage-rules/` folder in the fetched package), running `mix usage_rules.sync` is a required change.

Check the PR's CI with `gh pr checks`.

## 4. Report

Give a table with one row per update: the dependency, old → new version, the main changes, and the impact on our code, or "none". Then list the required changes and the optional cleanups, each with `file:line`. End with your recommendation: merge as is, or merge after the changes.

Don't change anything until the user agrees. The changes go on the PR's branch, for example in a worktree created with `wt switch pr:<number>`.
