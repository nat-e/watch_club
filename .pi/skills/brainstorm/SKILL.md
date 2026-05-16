---
name: brainstorm
description: Runs a manually invoked Socratic brainstorming workflow for new features, technical changes, UI/UX concepts, and refactors in WatchClub. Use only when invoked explicitly with /skill:brainstorm; do not load automatically.
disable-model-invocation: true
---

# Brainstorm

Use this skill to turn a brief feature or technical-change idea into a concise PRD plus, when useful, temporary Storybook mockups for review in Plannotator.

## Entry point

- The user should invoke this manually, preferably with a short brief: `/skill:brainstorm <idea>`.
- If no brief is provided, ask for a one-paragraph description before exploring.
- Treat invocation as permission to create only temporary brainstorm artifacts:
  - `tmp/brainstorm/<slug>/prd.md`
  - `lib/watch_club_web/storybook/brainstorm/<slug>.story.exs`
- Do not modify real app/domain code unless the user separately approves implementation.

## Required context pass

Before proposing a design:

1. Read `CONTEXT.md` and use its Ubiquitous Language. Challenge conflicting terms immediately.
2. Read relevant project docs and source code for the feature area.
3. For Ash or Phoenix questions, consult project docs with `mix usage_rules.docs` or `mix usage_rules.search_docs` before relying on memory.
4. Research web/best-practice sources only when the design depends on external product, UX, security, performance, or industry conventions. Cite sources briefly only when they affect a decision.

## Socratic interview

- Challenge assumptions, boundaries, terminology, risks, and alternatives.
- Ask one question at a time only when the answer materially changes the domain model, UX flow, or implementation architecture.
- If code/docs can answer a question, inspect them instead of asking.
- For minor uncertainty, proceed with an explicit assumption in the PRD.
- Prefer design-review momentum over gatekeeping every ambiguity.

## PRD artifact

Write a short PRD to `tmp/brainstorm/<slug>/prd.md`. The user should be able to skim it quickly; remove everything that does not change.

Use this structure, omitting any section that adds no decision value:

1. **Problem / goal** — one sentence.
2. **Non-goals** — omit unless the user explicitly specified non-goals in the conversation.
3. **Key decisions to validate** — short checklist of decisions that materially shape the domain model, UX, or architecture.
4. **Domain Changes** — only changed domain functions/resources/actions/attributes/relationships/policies/PubSub events. If nothing changes, write one sentence saying no domain changes and what existing behavior is reused.
5. **Web App Changes**
   - Start with the affected UI's component tree, not the file/module hierarchy.
   - Show it as a `diff` fenced block so `+`, `-`, and `~` lines are colorized.
   - Use component names and short same-line comments only; do not show HEEX/code, attributes, params, or implementation snippets.
   - Show only structural changes that help the user understand the page/modal layout.
   - Example format:

     ```diff
       Layouts.centered_card
       ├─ <.stack>                         # header / context
     ~ │  └─ instructions                  # copy changes
     + ├─ <.segmented_control>             # mode switch
     + │  ├─ item: Create account
     + │  └─ item: Sign in
       ├─ <.registration_form>             # registration mode only
     ~ └─ <.sign_in_form>                  # sign-in behavior changes
     ```

   - Then list only changed params/events/assigns/components in concise bullets.
6. **Mockups** — Storybook path/link, or “No mockup needed” for backend-only changes. Mention variants only when they represent a real design choice.
7. **Validated implementation notes** — use instead of “Risks / open questions”. Research and validate uncertainties before writing the PRD; summarize the chosen solution in one short paragraph or bullets.

Avoid implementation detail unless it helps the user validate a design decision.

## Storybook mockups

- Create Storybook mockups for user-facing UI/UX changes.
- Use temporary files under `lib/watch_club_web/storybook/brainstorm/` and label them temporary in module docs/comments.
- Follow existing PhoenixStorybook patterns in `lib/watch_club_web/storybook`.
- Use WatchClub design-system tokens from `docs/design-system/foundation.md` and existing UI primitives where practical.
- Include Storybook links in the PRD, normally `http://localhost:4000/dev/storybook/brainstorm/<slug>`.
- If the dev server is not running, still include the link and note that it requires the Phoenix dev server.

## Plannotator review

After writing the PRD and any mockups:

1. Run `plannotator annotate tmp/brainstorm/<slug>/prd.md`.
2. Ensure the PRD contains the Storybook mockup links before review.
3. Incorporate returned annotations into the PRD and/or proposed design.
4. Summarize final artifacts and remaining decisions for the user.

## Completion response

End with:

- PRD path.
- Storybook mockup path and link, if created.
- What changed after Plannotator review.
- The smallest set of decisions still needed before implementation.
