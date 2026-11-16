# Contributing

## Reporting bugs

Open a [GitHub issue](https://github.com/nat-e/watch_club/issues). For security problems, follow [SECURITY.md](SECURITY.md) instead.

## Setup

1. Install [mise](https://mise.jdx.dev) and run `mise install`. It installs Erlang, Elixir, Node, Biome and ffmpeg at the versions in `mise.lock`. The Docker image ships the same ffmpeg.
2. Install Chromaprint's `fpcalc` and Git LFS, for example with `brew install chromaprint git-lfs`, and Docker.
3. Copy `.env.example.dev` to `.env`, and set `WC_TMDB_API_KEY`.
4. Start Postgres, for example with `docker compose -f docker-compose.dev.yml up -d db`.
5. Run `mix setup`. It also seeds the database with the dev catalog: see [dev/catalog/README.md](dev/catalog/README.md).

## Checks

`mix ci` runs every check that CI runs: compilation without warnings, formatting, unused dependencies, Credo, Gettext and Ash codegen being up to date, Biome, and the tests. Run it before opening a pull request.

CI also builds the Docker image, starts it with `docker-compose.yml` and checks that the app responds.

## Translations

The app is translated into English and French with Gettext. After changing text in the code:

1. Run `mix gettext.extract --merge` to update the `.po` files in `priv/gettext/`.
2. Fill in the `msgstr` of the new messages.

## Pull request titles

Pull requests are squash merged, so the title becomes the commit message on `main`. [release-please](https://github.com/googleapis/release-please) reads these messages to pick the next version and write `CHANGELOG.md`, so titles must follow [Conventional Commits](https://www.conventionalcommits.org):

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
- `chore(deps): update ash to 3.38`

A CI check rejects titles that don't follow this format.
