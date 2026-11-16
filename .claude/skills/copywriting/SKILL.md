---
name: copywriting
description: "Write WatchClub's interface text in English and French, and translate it with i18next. Use before writing or changing interface text or the translation files."
---

Write WatchClub's interface text in English and French. Use the terms in `CONTEXT.md`.

When the Phoenix app, `~/dev/watch_club`, already shows a message, copy its English and French from `priv/gettext`, even where it departs from these rules or `CONTEXT.md`.

## Voice

- Warm, like a friend running the club. Keep it plain: no jokes, slang or marketing claims.
- WatchClub speaks as "we" ("on" in French). Users don't need to know it is self-hosted: name the Instance Administrator only when the user has to contact them.
- French uses "tu".

## Words

- Name the type when the text is about one movie or TV show: "this movie", "cette série". In French, this also sets the gender of the words around it.
- Say "content" ("contenu") for movies, TV shows and sports events together, not "titles". French calls a sports event "contenu" too.

## Say what it's for, then one action

- Explain what a feature does for the user before how to use it: "Request a movie or a TV show: we'll look for it and add it here for everyone", not "Search for a title in Browse and request it."
- Leave navigation to buttons and links. Don't describe where controls are ("in Browse", "from its page") when a button can take the user there.
- Give steps only when the task is unfamiliar or the order matters, such as casting to a TV.

## Match the moment

- First use: one or two sentences on what goes here and why it's useful, then one action.
- Returning users: short labels and states. Don't explain the concept again.
- Confirmations: say what happened and who it affects.
- Errors: say what went wrong and what the user can do, in plain words, with no warmth that hides the problem.
- Deleting, sharing and anything hard to undo: state the consequence before the user confirms.

## Translation

- Put all interface text in the translation files, `src/l10n/en-us.ts` and `fr-fr.ts`, including attributes such as `aria-label`, `title`, `placeholder` and `alt`, and the text of the components shadcn/ui generates. Only the name WatchClub stays as is.
- Put the text both apps show in `packages/core`, the `core` namespace, and each app's own text in the app's namespace. Group messages by screen, with camelCase keys: `t($ => $.core.signIn.title)`.
- Translate whole sentences, never parts of sentences, because word order changes between languages. Pass values as `{{variables}}`. Write plurals as `_one` and `_other` keys chosen by `count`, and French words whose gender depends on a value as context keys, such as `_movie` and `_tvShow`.
- Say the same thing in both languages. Write French as a French speaker would, rather than translating English word for word.
- In French, put a non-breaking space (U+00A0) before `:`, `;`, `!` and `?`, after « and before », so no punctuation mark wraps onto a line of its own.
