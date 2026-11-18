---
name: review
description: "Start subagents to review a PR or set of changes."
---

Start all the relevant reviewer agents: `software-design-reviewer`and `bug-reviewer`, Rust changes with `rust-reviewer`, API changes with `openapi-reviewer`, TypeScript changes with `typescript-reviewer`, database changes with `database-reviewer` and interface text with `copywriting-reviewer`.

Give each reviewer the change and the context it needs, tell it explicitely to only focus on its area of expertise, and not to review bug, behavior or other general-purpose review unless it is it's area of focus.

If multiple reviewers disagree, have them communicate to agree on a solution. Fix all the straight forward findings in a separate commit, and ask the user for direction when trade-offs are involved.

You should in general favor keeping the codebase simple and readable rather than trying to support all possible, corner cases. Especially when the solution makes the interfaces more complex. Sometimes a comment explaining that this corner case exists and is not supported is better.
Ask the agents a re-review when there findings have been fixed. Stop when they all give you an LGTM.
