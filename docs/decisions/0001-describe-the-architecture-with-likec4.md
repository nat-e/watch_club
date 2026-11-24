# 1. Describe the architecture with a LikeC4 model

- Status: Accepted
- Date: 2026-11-23

## Context

WatchClub's docs were prose: the README, the guides in `docs/` and a glossary. None showed how the apps, the server and the systems they call fit together.

Agents write most of the code, from plans we agree on in their chat. A plan stays in that chat, so a reviewer can't see it, and later sessions can't find it.

Diagrams drawn by hand, such as Mermaid in Markdown, drift apart: each one repeats the elements, and nothing checks them.

## Decision

One [LikeC4](https://likec4.dev) model, in [`docs/architecture`](../architecture), describes WatchClub at the levels of the [C4 model](https://c4model.com): who uses it and the systems it calls, its containers, the server's components (one per domain), its main flows and its deployment. Its elements use the terms of the data model, `docs/data-model.md`, and what the data model describes but isn't built yet is tagged `#planned`.

- Each domain of the server has its file, such as `contents.c4`. The views, in reading order, are in `views.c4`.
- `pnpm fix` draws the views as Mermaid diagrams in `docs/architecture/README.md`, which GitHub shows. `pnpm check`, which CI runs, validates the model and fails when the README doesn't match it.
- `pnpm c4` opens the views in LikeC4's viewer, with each element's description and technology, and the flows step by step.
- C4 leaves the code level to other notations. Each domain's code is in `docs/architecture/domains`, such as `accounts.md`: its modules, with the structs and functions that help understand them, as a tree written by hand. The database's tables are in the data model, as Mermaid diagrams written by hand.
- Decisions that shape WatchClub go in `docs/decisions`, one numbered file each, in the format of this one.

A change to the architecture starts with its docs: the data model, the architecture model, and a decision when it makes one. They come in the first commit of its pull request, so we review the plan before the code.

## Options considered

- **Mermaid diagrams written by hand**: nothing to install, but each diagram repeats its elements, and they drift apart.
- **Structurizr DSL**, the C4 model's own tool: its tools come as a Java app or a Docker image, outside our JavaScript and Rust toolchains.
- **A docs site**, such as Astro Starlight with LikeC4's Vite plugin: interactive diagrams beside every guide, but another app to build and host, and GitHub Pages already serves the Cast receiver.

## Consequences

- Every diagram comes from one model, so they can't disagree, and pull requests show changes to the architecture as text.
- Agents can query the model through LikeC4's MCP server, `likec4 mcp`.
- On GitHub, the diagrams leave out descriptions and technologies, and the flows lose the order of their steps. The `.c4` files and `pnpm c4` show them in full. LikeC4 has an open request to draw flows as Mermaid sequence diagrams: [likec4/likec4#3359](https://github.com/likec4/likec4/issues/3359).
- We write the model by hand. The check catches a broken model, not one that no longer matches the code: reviews must catch that.
