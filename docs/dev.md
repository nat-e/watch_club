# Development Environment

Install [mise](https://mise.jdx.dev) and Docker, then run the app:

1. Copy `.env.example` to `.env`, then install the tools and dependencies: `mise trust && mise install && pnpm install`
2. Start Postgres in Docker: `pnpm dev:shared`
3. Create the database and add the `admin` user: `sqlx database setup --source apps/server/migrations && pnpm --filter server seed`
4. Run the server and the web app: `pnpm dev`, or `pnpm dev --expo` to also run the mobile app's dev server

Sign in as `admin`, with the password `passw0rd`.

## Worktrees

We use [Worktrunk](https://worktrunk.dev) to work on several branches at once, each in its own worktree. `wt switch --create <branch>` creates and sets one up.

In each worktree, `pnpm dev` runs its own server and web app, on ports of their own. To save resources, the mobile app's dev server only runs with `pnpm dev --expo`.

### Database

Each worktree has its own database in the shared Postgres, created with the migrations and the `admin` user. Data you add in a worktree stays in it, and removing the worktree deletes its database.

### Web app

Each worktree's web app runs at `http://<branch>.localhost:<port>`, and `wt list` shows the URLs. Browsers keep cookies per domain, so each worktree has its own sessions. `wt open` opens the web app.

### Mobile app

The mobile app runs in a development build made with `expo-dev-client`, not in Expo Go: Expo Go ships its own, older native libraries, so the app would behave differently. One build serves every worktree: it lists their dev servers, and you can switch between them. To build it for Android, install Android Studio, and set `JAVA_HOME` to its Java (`/Applications/Android Studio.app/Contents/jbr/Contents/Home` on macOS) and `ANDROID_HOME` to its SDK (`~/Library/Android/sdk`). Then connect a phone or start an emulator, and run `turbo run android --filter=mobile`. Rebuild it only when native code changes.

## Dev catalog

The repo comes with an optional catalog of free-licensed clips to try the app with: movies, TV shows and sports events in many codecs and formats. `pnpm catalog` downloads them from Git LFS (about 800 MB), and runs Radarr, Sonarr and Sportarr with them, at `localhost:4103`, `4104` and `4105`.

The worktrees share the catalog, so a change made in one worktree shows in all of them. `pnpm catalog:reset` undoes every change.

The three apps start from a snapshot, which for now comes from the Phoenix app's `mix dev.catalog.seed`.
