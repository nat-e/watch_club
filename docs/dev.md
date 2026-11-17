# Development Environment

To run the app:

1. Copy `.env.example` to `.env`, then install the tools and dependencies: `mise trust && mise install && pnpm install`
2. Start the shared services in Docker (Postgres, Radarr, Sonarr and Sportarr): `pnpm dev:shared`
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

The mobile app runs in a development build made with `expo-dev-client`, not in Expo Go: Expo Go ships its own, older native libraries, so the app would behave differently. One build serves every worktree: it lists their dev servers, and you can switch between them. Build it with `turbo run android --filter=mobile`, and rebuild it only when native code changes.

## Dev catalog

The repo comes with a catalog of free-licensed clips to try the app with: movies, TV shows and sports events in many codecs and formats. Git LFS stores them (about 800 MB). The first `pnpm dev:shared` downloads them and loads them into Radarr, Sonarr and Sportarr from a snapshot. The three apps run at `localhost:4103`, `4104` and `4105`, without signing in.

The worktrees share the clips and the three apps, so a change made in one worktree shows in all of them. `pnpm catalog:reset` undoes every change.

For now, the snapshot comes from the Phoenix app's `mix dev.catalog.seed`. Without it, `pnpm dev:shared` only starts Postgres.
