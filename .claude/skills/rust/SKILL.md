---
name: rust
description: "Write idiomatic Rust in this app: axum, utoipa and SQLx at the versions it uses. Use before writing or changing Rust code."
---

Write code a seasoned Rust developer finds idiomatic, with types that make invalid states unrepresentable. Skip a guideline when following it only adds ceremony. Follow the rules in `AGENTS.md` first.

Check APIs against the sources for the versions in `Cargo.lock`, not from memory. Find dependency sources in `~/.cargo/registry/src/*/<crate>-<version>/`.

Read the reference that matches the work:

- **axum and utoipa**: Read the docs in the crate sources, such as axum's `src/docs/` and utoipa-gen's `src/lib.rs` for the `#[utoipa::path]` attributes. Every endpoint is a handler with `#[utoipa::path]`, registered with `utoipa_axum::routes!`, so the OpenAPI document the apps' client comes from describes it; the types it reads and returns derive `ToSchema`. List every status it can send in `responses`, except the 400 for a bad body, the 401 of an endpoint whose `security` requires a session, and the 500: `openapi::add_error_responses` adds them
- **SQLx**: Read `references/sqlx.md` for our patterns and the pitfalls we hit
- **Idioms**: Read `references/pragmatic-rust-guidelines.md`, Microsoft's Pragmatic Rust Guidelines. It's about 34k tokens. Search for the topic, such as errors, newtypes or panics, and read only the matching guidelines. Skip the sections on FFI, macros, building libraries, library interoperability and projects, the `unsafe` guidelines (`Cargo.toml` forbids `unsafe`), and M-CANONICAL-DOCS, M-FIRST-DOC-SENTENCE, M-MIMALLOC-APPS, M-MODULE-DOCS and M-TARGET-CPU

Start each module with a `//!` summary. Start a function's doc comment with a third-person verb ("Returns the…") and a type's, constant's, field's or variant's with a noun phrase ("The information…"), or a boolean's with "Whether". Start no doc comment with "What", "How", "Why" or "Who".

After upgrading SQLx, check `sqlx.md`.
