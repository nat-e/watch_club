# SQLx 0.9 in this app

Official docs: the [`query!` macros](https://docs.rs/sqlx/0.9.0/sqlx/macro.query.html), the [FAQ](https://github.com/launchbadge/sqlx/blob/v0.9.0/FAQ.md) and [migrations](https://docs.rs/sqlx/0.9.0/sqlx/macro.migrate.html).

## Queries

- Use `query!`, `query_as!`, and `query_scalar!` to check SQL and its types against `DATABASE_URL` at compile time. Run `sqlx migrate run` before querying a new column
- `apps/server/sqlx.toml` ([reference](https://docs.rs/sqlx/0.9.0/sqlx/_config/index.html), feature `sqlx-toml`) gives table columns their Rust types, such as `users.id` as `UserId`, and `timestamptz` the type `jiff_sqlx::Timestamp`. Add a column there when it gets a newtype. Its paths start with `::watch_club`, which `lib.rs` declares for itself with `extern crate self`
- Table overrides only reach output columns that come from a table, even through joins, subqueries and CTEs. Name the type of a computed column in its alias: `AS "id: UserId"`. Nullability overrides still apply: `"title!"` for not null, `"username?"` for nullable
- SQLx infers nullability from the table's `NOT NULL` and Postgres's plan. Add `!` where the data can't be null and `?` where it can, only when the compiler shows SQLx got it wrong: expressions such as `count(*)` and `EXISTS`, nullable columns a `WHERE … IS NOT NULL` filters, and some `LEFT JOIN`s
- Bind newtypes with `id as UserId` and slices with `&ids as &[UserId]` (then `= ANY($1)`). Parameters don't get table overrides. Use `value as _` to skip the type check
- Postgres rejects `ORDER BY` on an expression right after `UNION ALL`. Wrap the union in a subquery and sort it

## Types

- IDs: `#[derive(sqlx::Type)] #[sqlx(transparent)] pub struct UserId(Uuid);`
- Text enums: `#[derive(sqlx::Type)] #[sqlx(type_name = "text", rename_all = "snake_case")]`, or `#[sqlx(rename = "en_US")]` per variant
- Times: SQLx 0.9 has no Jiff support, so `jiff-sqlx` wraps the types. `sqlx.toml` maps `timestamptz` to `jiff_sqlx::Timestamp`: call `.to_jiff()` on what you select, and bind `jiff_sqlx::Timestamp::from(time)`
- A unique violation: match `sqlx::Error::Database(error) if error.is_unique_violation()`

## Migrations

- `sqlx migrate add --source apps/server/migrations <name>` creates `apps/server/migrations/<timestamp>_<name>.sql`. Migrations only go forward
- `sqlx database setup --source apps/server/migrations` creates the database and runs migrations. The app also runs pending migrations at startup through `watch_club::connect_database`

## Offline data

- The Docker build compiles without a database, from the query data in `.sqlx/`. After adding or changing a query, run `cargo sqlx prepare -- --all-targets --all-features` in `apps/server` and commit `apps/server/.sqlx/`

## Tests

- Give a `#[tokio::test]` its own database with `testing::database()`, which creates it with the migrations and drops it with its pool. Not `#[sqlx::test]`: it names a test's database after the test alone, so two worktrees running the same test on the Postgres they share would drop each other's
