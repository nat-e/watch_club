---
name: brainstorm
description: Runs a manually invoked Socratic brainstorming workflow for new features, technical changes, UI/UX concepts, and refactors in WatchClub. Use only when invoked explicitly with /skill:brainstorm; do not load automatically.
disable-model-invocation: true
---

# Brainstorm

Use this skill to turn a brief feature or technical-change idea into a concise PRD.

## Entry point

- The user should invoke this manually, preferably with a short brief: `/skill:brainstorm <idea>`.
- If no brief is provided, ask for a one-paragraph description before exploring.
- Treat invocation as permission to create only temporary brainstorm artifacts:
  - Always: `tmp/brainstorm/<slug>/prd.md`
  - Optional, only for meaningful UX changes: Create a page in the product for mocking up and validating different UIX propositions.

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

## Mockups

- Create mockups only when there is a meaningful UX decision to validate visually, such as new layout, flow, interaction model, information hierarchy, or visual treatment.
- Do not create mockups for backend-only changes, copy-only changes, small helper changes, or UI changes whose visible effect can be explained with examples in the PRD.
- Follow existing UX patterns for coherence with the rest of the application
- Use WatchClub design-system tokens from `docs/design-system/foundation.md` and existing UI primitives where practical.
- Use hardcoded realistic data for a realistic result. Don't include "meta" data explaining your design inside the UI. This belongs in the PRD

## Completion

End with:

- PRD path.
- Mockup path and link, if created.
- Iterate on the user feedback
