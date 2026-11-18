# LLM Instructions

- Load the `software-design` skill and read `a-philosophy-of-software-design.md` before writing any code
- Load the `rust` skill before writing Rust
- Load the `typescript` skill before writing TypeScript
- Load the `copywriting` skill before writing interface text, in components or in the translation files
- Load the `database` skill before writing SQL, migrations or code that reads or writes the database

## Worktrees and Local Server

- You work in one worktree: the current directory. Do not access other worktrees files or processes unless explicitely asked.
- Each worktree has its own ports, URL and database, in `.env`: `PORT`, `WEB_PORT`, `APP_URL` and `DATABASE_URL`. Sign in at `APP_URL` as `admin`, with the password `passw0rd`
- process-compose runs the worktree's dev processes, which `process-compose.yaml` describes: the server, the web app, and Expo's dev server when started.
- `pnpm dev` starts them unless they run. Then `process-compose project is-ready --wait` waits until they're ready: never wait with `sleep`
- The server restarts and the web app reloads by themselves when code changes: don't restart them
- `process-compose process logs server -n 200` reads a process's logs, `process-compose process restart server` restarts it, and `process-compose process start expo` starts Expo's dev server
- After changing `.env` or `process-compose.yaml`, run `process-compose down && pnpm dev`
- Never run the server or the web app another way, such as with `cargo run`, `vite` or `nohup`. Never stop a process by name, such as with `pkill` or `killall`: it stops other worktrees' processes too. `process-compose` only reaches this worktree's
- Never stop or restart the Docker containers, such as Postgres: all the worktrees share them

## Rules

- Do not modify `.harness` without being prompted to do so. Harness improvement is always done in a separate session.
- Be conservative with proposing documentation changes. All documentation outside `.harness` is intended for humans and must be written in a simple, concise style. The goal is not to be exhaustive, but to present the main features and decisions of the product. When proposing changes, make sure to write with the same tone and level of detail. Prefer reframing statements to pure additions that lead to AI-slop.
- Use terms in `CONTEXT.md` in code and docs, and avoid the synonyms it lists.
- Never log User's IP addresses, PII or secrets.
- When implementing client code, keep feature parity between web and mobile. Aim to share most business logic code in `packages/core` and keep the two client apps' files organized the same way, under the same folder names.
- Business logic, such as fetching what a poster card shows and deciding what it shows, goes in `packages/core`, in its domain's folder. Each app only draws it
- Commit messages and PR titles follow Conventional Commits (`feat: …`, `fix(inbox): …`)
- The rewrite lives on the `rust` branch of `nat-e/watch_club`, whose `main` is still the Phoenix app. Open pull requests against `rust`: `gh pr create --base rust`

## Coding Style

- Prefer explicit, easy to understand code to compact code.
- Use descriptive classes, functions, arguments and variable names.
- Use line breaks and flow to increase code readability.
