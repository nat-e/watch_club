Rewrite of WatchClub (`~/dev/watch_club`) with an axum server in Rust, a React web app and an Expo app for phones and TVs, in one Turborepo monorepo.

- `CONTEXT.md` is the domain glossary. Use its terms in code and docs, and avoid the synonyms it lists. UI texts should favor them unless a more user friendly alternative exists (i.e. Language instead of Locale).
- Load the `software-design` skill and read `a-philosophy-of-software-design.md` before writing any code
- Load the `rust` skill before writing Rust: it points to the guidelines and to the references for our versions
- Load the `typescript` skill before writing TypeScript
- Load the `copywriting` skill before writing interface text, in components or in the translation files
- Load the `database` skill before writing SQL, migrations or code that reads or writes the database

## Layout

- `apps/server`: the axum server with SQLx.
- `apps/web`: the web app, a Vite and React single-page app with TanStack Router and Query, and shadcn/ui
- `apps/mobile`: the Expo app for phones and TVs, with Expo Router and Uniwind
- `packages/api`: the API client, generated from the server's OpenAPI document, `openapi.json`. Run `pnpm generate` after changing the API and commit `openapi.json`. The tasks that need the client generate it from that file, without Rust; `pnpm check` fails when the file doesn't match the server's API
- `packages/core`: Shared business logic between both clients.

## Running

- `pnpm dev` runs the server and the web app's dev server at `APP_URL`, and reloads both on changes. Sign in as `admin`, with the password `passw0rd`
- `pnpm --filter server seed` fills an empty database with the Instance Administrator, `admin`
- `pnpm dev --expo` also runs Expo's dev server; `turbo run android --filter=mobile` builds the app and runs it on Android. Run them through turbo, which generates the API client first. Turbo shows each task in its own pane: select Expo's and press `i` to send it keys, `Ctrl+Z` to stop. Expo's dev server forwards `/api` to the server, and the app in development connects through it rather than asking for an address
- The app runs in its development build, not in Expo Go, whose native modules are older than ours. One build serves every worktree: its launcher lists their dev servers by branch. Rebuild it only when native code changes: a native package, the native settings in `app.json` or the Expo SDK
- `pnpm check` runs Biome, rustfmt, the type checks, Clippy and `i18next-cli`, which checks the translations against the code; `pnpm test` runs the tests, and `pnpm fix` formats and sorts the translations
- After changing a query, run `cargo sqlx prepare -- --all-targets --all-features` in `apps/server` and commit `apps/server/.sqlx`: the Docker build has no database

## Server

### Errors

- An operation returns its own `thiserror` enum when callers handle its failures, with an `Internal(#[from] anyhow::Error)` variant for the rest. Otherwise it returns `InternalError`. Use `.context(…)` to say what failed

### Metadata Providers

- Each Metadata Provider has a gateway in `src/domain/contents/metadata_providers/`, written for what the domain needs rather than mirroring the service's API: it takes and returns domain types and errors, and keeps the service's JSON in a private `api` module. It calls the service through `integrations/http.rs`, which retries and traces the calls

### Logs

- Name each event, and keep its message the same every time: put the values in fields, under OpenTelemetry's names where it has one, such as `server.port`. Put an error with its causes in `exception.message = %format_args!("{error:#}")`
- Never log IP addresses, passwords or session tokens
- Record text that users typed as a plain string, without `%`: the console then quotes and escapes it, so a line break in it can't forge another log line
- Write named events with `tracing::event!` and a `Level`: `info!`, `warn!` and `error!` can't take a dotted field first after `name:` until tokio-rs/tracing#3407 is fixed
- Give work that runs apart from requests a span with its identity, and run it in `observability::with_error_scope`, as `jobs/observability.rs` does

### Jobs

- Run background and recurring work as a job, in `src/jobs/kinds/`. `src/jobs.rs` says how to add one

## Web and mobile apps

- Keep the two apps' files organized the same way, under the same folder names, so a component's counterpart is easy to find
- `src/routes` (web) and `src/app` (mobile) hold only routes: Expo Router makes every file in `src/app` a screen. Keep route files thin: they read the URL, call hooks and put components together. A component only one route uses stays in its route file until it grows, then moves to `src/components`
- `src/components` holds the components that routes share:
  - `layouts/`: the frame of a page or screen, such as web's `Page` or mobile's `FormScreen`
  - `forms/`, `lists/`: generic controls, grouped by kind
  - a folder per domain, named as in `CONTEXT.md`, such as `contents/`, for the components that show it, such as a poster card
  - `ui/` (web): shadcn's components in its Vega style, as its CLI writes them. Change their look only through the theme, `packages/core/src/theme.css` and `apps/web/src/index.css`, or through classes where we use them. Edit their files only for what isn't style, such as translating their texts
- Business logic, such as fetching what a poster card shows and deciding what it shows, goes in `packages/core`, in its domain's folder. Each app only draws it

## Mobile app

- Prefer the platform's own components: Expo Router's native stack and tabs, `@expo/ui`'s controls inside the `Host` of `@/components/host`, and SF Symbols and Material Symbols for icons. Draw with React Native's views and Uniwind only what `@expo/ui` doesn't offer, such as the app's own content

## Tests

- Write the server's tests in the single test crate `apps/server/tests/integration/`, whose files mirror `src/`
- Test the domain through its public functions, one file per module in `domain/`
- Test the API through requests to the app's router with `support::Client`, one file per endpoint in `routes/`: check the status and the JSON
- Add unit tests only for private logic that's hard to reach that way. They don't use the database: split such logic from its queries, and test the queries through the public functions
- Test TypeScript with Vitest, in `.test.ts` files in the package's `tests/` folder, beside `src/`, whose files mirror `src/`

## Naming

## Docs

Documentations for the project is in `docs`, organized per topic.

## Git

- The rewrite lives on the `rust` branch of `nat-e/watch_club`, whose `main` is still the Phoenix app. Open pull requests against `rust`: `gh pr create --base rust`
- Commit messages and PR titles follow Conventional Commits (`feat: …`, `fix(inbox): …`)
