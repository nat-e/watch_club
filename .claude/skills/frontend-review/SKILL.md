---
name: frontend-review
description: Review a Phoenix LiveView or component from HTML, CSS and UX perspective.
---

Look for **structural** improvements, not only local / cosmetic ones. Ask "what is the ideal composition" for this screen or component — if you were free to rewrite it from scratch in this codebase, would you write it exactly like this? Restructure only when it clearly improves readability, reuse, or correctness — not for taste.

## Before reviewing
Read `@docs/design-system/foundation.md` and skim shared components and UI primitives, so you know what's available to compose with. Treat a long raw `flex`/`grid` class string as a smell to replace with a primitive, not a constraint.

## Verify in the browser — don't assert from source
Render it in the running app (chrome-devtools). Screenshot at ~375 / 768 / 1440 and test realistic and edge content: long titles, many items, empty/loading/error states. Inspect computed `display`/`flex`/width to confirm claims instead of guessing from classes.
You can login with kotor/passw0rd locally.

## Look for
**Source code**
- Readability: clear naming, components extracted, comments only where they earn their place.
- Simplicity: lean markup, no extra wrappers, simple CSS — prefer flex to grid unless 2-D is needed.
- Reuse: compose shared components (`<.button>`, `<.badge>`, `<.tmdb_poster>`, `<.stack>`/`<.inline>`/`<.cluster>`) and design tokens.

**UX**
- Responsive at every width (no overlap, clipping, stray scrollbars), driven by container queries — viewport `svh` and capability queries like `@media(hover:hover)` are fine.
- Hierarchy: the most important thing stands out; spacing conveys relationships.
- Accessibility: semantic elements over div soup, `aria-label` on icon-only controls, alt text, sane focus order.
- Follows `@docs/design-system/foundation.md`.

## Report
Lead with the 1-3 structural rewrites (each with a concrete before/after), then local cleanups. Give `file:line` and a specific change for every finding.
