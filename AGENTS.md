This is a web application written using the following tech stack:
- Elixir
- Phoenix Web framework
- Ash for modeling the domain
- LiveView for UX
- Tailwind CSS for styling

Rules:
- Always read source code and docs before answering. Use `mix usage_rules.docs` and `mix usage_rules.search_docs` for searching docs
- When asked about a bug or issue, always debug and verify your hypothesis, do not guess

## i18n

- We use Gettext for internationalization. The app is currently translated in English (default) and French
- Comment messages with `# AI-translated (Claude)` when translating in the .po files
- Translate whole sentences, never parts of sentences, because word order changes between languages. When a sentence contains components (links, user names...), put them in placeholders with `gtcomponent/1` and render the result with `raw/1`: `raw(dgettext("feed", "%{user} joined the club", user: gtcomponent(user_ref(%{user: user}))))`

## Coding style

### Frontend

- Inline the CSS styles directly in the HEEX templates. Do not extract them to elixir functions, this makes the code harder to read and comprehend. If you find yourself duplicating them, it is often a sign that you need to extract a function component.
- Use tailwind classes based onsemantic token from our design system as defined in `@docs/design-system/foundations.md`
- Avoid long list of assigns in live views / live components. Prefer deriving data directly at the call site inline inside the component. When in need of many related assigns, consider creating a struct or Ash Resource for managing them. Try to extract business logic inside testable Ash resources.
- Make sure to always make UI responsive. Use Tailwind container queries rather than absolute breakpoints.
- Prefer simpler `flex` layouts instead of `grid` when possible.

### Data Loading

- When loading data to display in pages that shouldn't fail (no user input), prefer ! bang version instead of handling error explicitely
- When loading data based on user input (form, url params, ...), errors are expected and you must handle them
- When submitting form, always handle the error case and update the form in the assigns
- When submitting actions that shouldn't fail (gated by UX), or very low chances with no possible mitigation, prefer ! bang versions.

### Backend

- Only add policies and Ash authorizers to resources when it adds meaningful value. Policies like "any logged in user can do any action" does not bring value.

## Coding guidelines

- Focus on readability and maintainability of the code and clear separation of concerns.
- Don't code defensively, follow Elixir's mantra and "let it crash". Only handle "expected" errors explicitely
- Refrain from extracting small helper functions, this creates a lot of indirections which makes the code harder to read and reason about. Only extract code to helper functions when it will be reused, or when it is substantial enough that it makes the code easier to reason about.
- Helper names should describe what they do in the project's vocabulary, not generic mechanics. `unwrap_async_result` or `normalize_value` are shape descriptions, not meaning descriptions — prefer a name like `set_outcome_for_timeout` (or inline the code if short enough).

## Tests

We write tests for all the functions exposed in our Ash domains and only for those.

- Do not create resources and domain actions only to be used by tests. Tests can use `seed_generator` when they need to do something not exposed by the domain.
- Do not write tests to test simple read actions
- One test per resource, that tests all the functions defined in this resource
- One `describe <function_name/*>` block per function
- Write one test for the happy case, and tests for valuable error cases (e.g. invalid inputs, policies...). Do not write error cases for tests that would just verify the framework (e.g., testing that a required field is present, or that a simple constraint is matched)
- For happy case, use the `!` version of functions for brievity
- For the error cases, write one test per case, do not write a single test that verifies multiple error cases
- Use the non ! version of functions and `assert_has_error` to verify the errors
- Use generators to seed test data and only call the function being tested. Only override the generator parameters that are relevant to the test case to value brievity and readability.


## Documentation

- Comments and docs should be concise and only document the current state of the code. Conversation details or changes compared to past implementations should not be reflected in documentation.

## Pull requests

- PR titles follow Conventional Commits (`fix: …`, `feat(player): …`), because release-please builds versions and the changelog from them. See `CONTRIBUTING.md`
- `mix ci` runs every check CI runs
