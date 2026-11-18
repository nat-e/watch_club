---
name: turborepo
description: Configure and troubleshoot Turborepo repositories. Use when working with turbo.json, task pipelines, caching, Remote Cache, the turbo CLI, filtering, environment variables, package boundaries, monorepo structure, or CI workflows.
---

# Turborepo

The complete Turborepo documentation ships inside the installed `turbo` package. Do not rely on this skill for framework guidance. Always read the bundled docs, which match the installed version exactly.

In this repository, mise installs `turbo` (see `mise.toml`), outside `node_modules`. Start with:

```sh
cat "$(mise where npm:turbo)/node_modules/turbo/docs/README.md"
```

Use that task index to choose the smallest relevant documentation page. Read it before changing Turborepo configuration, package scripts, or CI workflows.

If `turbo` is not installed, run `mise install`. After installation, use the bundled docs rather than guidance for a different release.
