# 2. Describe each domain in the data model

- Status: Accepted
- Date: 2026-11-24

## Context

Two files described the domain: `CONTEXT.md`, a glossary of its terms, the synonyms to avoid and its rules, and `docs/data-model.md`, the database's tables. They described the same concepts twice, and `CONTEXT.md` even defined Media and Media File twice.

## Decision

[`docs/data-model.md`](../data-model.md) is the only description of the domain. For each domain, it lists its terms, its rules and its tables. `CONTEXT.md` is gone, with its synonyms to avoid and its flagged ambiguities.

## Options considered

- **One file per kind of truth**: the glossary for the terms and rules, and the tables generated from the database with [tbls](https://github.com/k1LoW/tbls). The tables never drift, but a domain is described in two places.
- **Both files, as they were**: nothing to change, but each concept described twice.

## Consequences

- One file to read and update for a domain, with its terms beside its tables.
- Terms without a table, such as Instance, Inbox or Library, sit in the domain that uses them.
- We write the tables by hand: reviews must check that they match the migrations.
- Without a list of synonyms to avoid, reviews must catch them.
