# Contributing

## Reporting bugs

Open a [GitHub issue](https://github.com/nat-e/watch_club/issues). For security problems, follow [SECURITY.md](SECURITY.md) instead.

## Setup

See [docs/dev.md](docs/dev.md).

## Checks

`pnpm check` runs every check that CI runs: Biome, rustfmt, Clippy, the TypeScript type checks, the translations, and that `packages/api/openapi.json` matches the server's API. `pnpm test` runs the tests. Run both before opening a pull request. `pnpm fix` formats the code.

CI also builds the Docker image, starts it and checks that the app responds.

## Translations

The apps are translated into English and French with i18next. After changing text in the code:

1. Run `pnpm fix` to add the new messages to the `l10n` files of the app, or of `packages/core` for the messages both apps share.
2. Write their French translations.

## Pull requests

Open pull requests against the `rust` branch. They are squash merged, so the title becomes the commit message. [release-please](https://github.com/googleapis/release-please) reads these messages to pick the next version and write `CHANGELOG.md`, so titles must follow [Conventional Commits](https://www.conventionalcommits.org):

```
<type>(<optional scope>): <what changes>
```

| Type | Use for | Release |
| -- | -- | -- |
| `feat` | A new feature | Minor version (patch before 1.0) |
| `fix` | A bug fix | Patch version |
| `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`, `style`, `revert` | Everything else | None on its own |

Add `!` after the type for a breaking change, such as a new required setting: `feat!: …`. Before 1.0, breaking changes bump the minor version.

Examples:

- `fix: next episode returns the wrong episode`
- `feat(player): resume playback where you left off`
- `chore(deps): update axum`

A CI check rejects titles that don't follow this format.
