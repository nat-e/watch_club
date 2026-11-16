---
name: database
description: "Write WatchClub's Postgres code: queries, transactions, indexes and migrations. Use before writing or changing SQL, a migration or code that reads or writes the database."
---

Write database code a seasoned Postgres developer would approve: correct transactions, locks and concurrency, and efficient data loading. For SQLx itself, read the `rust` skill's `references/sqlx.md`.

- Keep indexes in line with queries: add the ones new queries need, and drop the ones no query uses.
- A pull request may add several migrations, one per scope. Until it merges, change its own migrations rather than adding new ones for intermediate states. After you edit a migration, run `sqlx database reset -y --source apps/server/migrations && pnpm --filter server seed`: SQLx refuses to start on a database where an earlier version of the migration ran. Each worktree has its own database.
