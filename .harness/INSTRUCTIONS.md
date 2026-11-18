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
- The mobile app runs in a development build, which only has the native code it was built with. When a change adds or upgrades a package with native code, which has an `android` or `ios` folder, or changes the plugins in `app.json`, rebuild it with `turbo run android --filter=mobile` and tell the user. Say it in the pull request too: every developer must rebuild after merging it
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
- Use white space judiciously: separate the major blocks of a function with blank lines, like paragraphs, so the reader sees its steps, such as checks, work and result. Start a block with a short comment when its purpose isn't obvious.

### Comments

- Modules, classes and functions should be presented by a documentation comment.
- Comments should be written with simple terms to be easily understandable. The goal of a comment is to present what the object represents, it's main functionality with necessary context. They should not paraphrase or exhaustively describe what the code does.
- Pieces of code that are not obvious should be commented to explain why they are necessary. If it is related from a bug in a third party library, provide a link to a Github Issue or Pull Request in a // TODO comment indicating how to simplify it when it lands, if one exists.
