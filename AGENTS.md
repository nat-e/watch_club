This is a web application written using the following tech stack:
- Elixir
- Phoenix Web framework
- Ash for modeling the domain
- LiveView for UX
- Tailwind CSS for styling

Rules:
- Do not modify any source code without being prompted to explicitely. Your role is to explain and provide guidance
- Always read source code and docs before answering. Use `mix usage_rules.docs` and `mix usage_rules.search_docs` for searching docs
- When asked about a bug or issue, always debug and verify your hypothesis, do not guess

## i18n

- We use Gettext for internationalization. The app is currently translated in English (default) and French
- Comment messages with `# AI-translated (Claude)` when translating in the .po files



## Planning changes

- Start by interviewing the user to understand their needs and requirements
- Focus on code architecture and design, not implementation details
- When multiple viable approaches are available and there is no clear project guidelines to decide, ask the user
- Use the `/plannotator` extension to present the design to the user and iterate on feedback

## Coding style

### CSS

- Inline the CSS styles directly in the HEEX templates. Do not extract them to elixir functions, this makes the code harder to read and comprehend. If you find yourself duplicating them, it is often a sign that you need to extract a function component.
- Use tailwind classes based onsemantic token from our design system as defined in `@docs/design-system/foundations.md`

## Coding guidelines

- Focus on readability and maintainability of the code and clear separation of concerns.
- Don't code defensively, follow Elixir's mantra and "let it crash". Only handle "expected" errors explicitely

## Tests

We write tests for all the functions exposed in our Ash domains and only for those.

- Do not create resources and domain actions only to be used by tests. Tests can use `seed_generator` when they need to do something not exposed by the domain.
- One test per resource, that tests all the functions defined in this resource
- One `describe <function_name/*>` block per function
- Write one test for the happy case, and tests for valuable error cases (e.g. invalid inputs, policies...). Do not write error cases for tests that would just verify the framework (e.g., testing that a required field is present, or that a simple constraint is matched)
- For happy case, use the `!` version of functions for brievity
- For the error cases, write one test per case, do not write a single test that verifies multiple error cases
- Use the non ! version of functions and `assert_has_error` to verify the errors
- Use generators to seed test data and only call the function being tested. Only override the generator parameters that are relevant to the test case to value brievity and readability.
