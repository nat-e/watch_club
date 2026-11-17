Rewrite of WatchClub (`~/dev/watch_club`) with an axum server in Rust, a React web app and an Expo app for phones and TVs, in one Turborepo monorepo.

- `CONTEXT.md` is the domain glossary. Use its terms in code and docs, and avoid the synonyms it lists. UI texts should favor them unless a more user friendly alternative exists (i.e. Language instead of Locale).
- Load the `software-design` skill and read `a-philosophy-of-software-design.md` before writing any code
- Load the `rust` skill before writing Rust: it points to the guidelines and to the references for our versions
- Load the `typescript` skill before writing TypeScript
- Load the `copywriting` skill before writing interface text, in components or in the translation files
- Load the `database` skill before writing SQL, migrations or code that reads or writes the database
- Review every meaningful change with `software-design-reviewer` and `bug-reviewer`, Rust changes with `rust-reviewer`, API changes with `openapi-reviewer`, TypeScript changes with `typescript-reviewer`, database changes with `database-reviewer` and interface text with `copywriting-reviewer`. Give each reviewer the change and the context it needs, but don't tell it what to report or skip, its own prompt sets its scope. Do not discard coding styles findings. When reviewer disagree, have them discuss until they agree.

## Layout

- `apps/server`: the axum server with SQLx.
- `apps/web`: the web app, a Vite and React single-page app with TanStack Router and Query, and shadcn/ui
- `apps/mobile`: the Expo app for phones and TVs, with Expo Router and Uniwind
- `packages/api`: the API client, generated from the server's OpenAPI document, `openapi.json`. Run `pnpm generate` after changing the API and commit `openapi.json`. The tasks that need the client generate it from that file, without Rust; `pnpm check` fails when the file doesn't match the server's API
- `packages/core`: Shared business logic between both clients.

## Running

- `pnpm dev` runs the server and the web app's dev server at `APP_URL`, and reloads both on changes. Sign in as `admin`, `alice`, `bob`, with the password `passw0rd`
- `pnpm --filter server seed` fills an empty database with the demo Users
- `pnpm dev --expo` also runs Expo's dev server; `turbo run android --filter=mobile` builds the app and runs it on Android. Run them through turbo, which generates the API client first. Turbo shows each task in its own pane: select Expo's and press `i` to send it keys, `Ctrl+Z` to stop. Expo's dev server forwards `/api` to the server, and the app in development connects through it rather than asking for an address
- `pnpm check` runs Biome, rustfmt, the type checks, Clippy and `i18next-cli`, which checks the translations against the code; `pnpm test` runs the tests, and `pnpm fix` formats and sorts the translations
- After changing a query, run `cargo sqlx prepare -- --all-targets --all-features` in `apps/server` and commit `apps/server/.sqlx`: the Docker build has no database

## Server

### Errors

- An operation returns its own `thiserror` enum when callers handle its failures, with an `Internal(#[from] anyhow::Error)` variant for the rest. Otherwise it returns `InternalError`. Use `.context(…)` to say what failed

## Mobile app

- Prefer the platform's own components: Expo Router's native stack and tabs, `@expo/ui`'s controls inside the `Host` of `@/components/host`, and SF Symbols and Material Symbols for icons. React Native's `Text`, `TextInput` and `ScrollView` are native too. Draw with Uniwind only what no native component offers, such as the app's own content

## Tests

- Write the server's tests in the single test crate `apps/server/tests/integration/`, whose files mirror `src/`
- Test the domain through its public functions, one file per module in `domain/`
- Test the API through requests to the app's router with `support::Client`, one file per endpoint in `routes/`: check the status and the JSON
- Add unit tests only for private logic that's hard to reach that way
- Test TypeScript with Vitest, in `.test.ts` files in the package's `tests/` folder, beside `src/`, whose files mirror `src/`

## Naming

## Git

- The rewrite lives on the `rust` branch of `nat-e/watch_club`, whose `main` is still the Phoenix app. Open pull requests against `rust`: `gh pr create --base rust`
- Commit messages and PR titles follow Conventional Commits (`feat: …`, `fix(inbox): …`)
