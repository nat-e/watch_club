# Contributing

## Setup

1. Install [mise](https://mise.jdx.dev) and run `mise install`. It installs Erlang, Elixir, Node and Biome at the versions in `mise.lock`.
2. Start Postgres, for example with `docker compose -f docker-compose.dev.yml up -d db`.
3. Run `mix setup`.

## Checks

`mix ci` runs every check that CI runs: compilation without warnings, formatting, Credo, security advisories, Gettext and Ash codegen being up to date, Biome, and the tests. Run it before opening a pull request.

CI also builds the Docker image, starts it with `docker-compose.yml` and checks that the app responds.

## Pull request titles

Pull requests are squash merged, so the title becomes the commit message on `main`. [release-please](https://github.com/googleapis/release-please) reads these messages to pick the next version and write `CHANGELOG.md`, so titles must follow [Conventional Commits](https://www.conventionalcommits.org):

```
<type>(<optional scope>): <what changes>
```

| Type | Use for | Release |
| -- | -- | -- |
| `feat` | A new feature | Minor version |
| `fix` | A bug fix | Patch version |
| `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`, `style`, `revert` | Everything else | None on its own |

Add `!` after the type for a breaking change, such as a new required setting: `feat!: …`. Before 1.0, breaking changes bump the minor version.

Examples:

- `fix: next episode returns the wrong episode`
- `feat(player): resume playback where you left off`
- `chore(deps): update ash to 3.38`

A CI check rejects titles that don't follow this format.

## Releases

release-please keeps a release pull request open, which bumps the version in `mix.exs` and updates `CHANGELOG.md`. Merging it tags the release, and CI publishes the image.

Images are published to `ghcr.io/nat-e/watch_club` with these tags:

| Tag | Points to |
| -- | -- |
| `latest` | The newest release |
| `1.2.3`, `1.2` | A release |
| `edge` | The latest commit on `main` |
| Commit SHA | That commit on `main` |

## Dependency updates

[Renovate](https://docs.renovatebot.com) (`renovate.json`) opens update PRs on Mondays, only for releases at least 7 days old:

- Patch updates and GitHub Actions updates: one PR each, which Renovate merges itself once CI passes.
- Minor updates, Erlang and Elixir, and Biome: one PR each, merged by hand. A new Biome version may need `biome migrate --write`.
- Major updates: one PR per dependency, merged by hand.
- `mix.lock` and `package-lock.json` maintenance: one PR, merged by hand.

Updates to production mix dependencies and to the `Dockerfile` are titled `fix(deps): …`, so they appear in the changelog. The "Dependency Dashboard" issue lists pending updates.
