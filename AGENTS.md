This is a web application written using the following tech stack:
- Elixir
- Phoenix Web framework
- Ash for modeling the domain
- LiveView for UX
- Tailwind CSS for styling

Rules:
- Always read source code and docs before answering. Use `mix usage_rules.docs` and `mix usage_rules.search_docs` for searching docs
- When asked about a bug or issue, always debug and verify your hypothesis, do not guess
- `CONTEXT.md` is the domain glossary. Use its terms in code, UI text and docs, and avoid the synonyms it lists

## Dev server

- The app runs at `WC_URL` from `.env`, or at `http://localhost:<WC_PORT>` when `WC_URL` is unset
- To log in: on an empty database, `/setup` creates the instance administrator. Otherwise, create an invitation code with `WatchClub.Accounts.create_invitation_code` and register a user with it through `register_with_password`

## Worktrees

- `wt switch --create <branch>` creates a worktree with its own server and databases. `wt dev` starts the server and `wt remove` deletes the worktree. The hooks are in `.config/wt.toml` and `scripts/worktree/`
- Each worktree's `.env` holds its URL, port and database names
- Radarr, Sonarr and `media/` are shared with main and every other worktree, so changes to them affect all of them
- After a merge, the `post-merge` hook updates main with `scripts/worktree/update_main.sh`. Main's dev server needs a restart to pick up new dependencies or config
- To restart a dev server, stop it, wait for `WC_PORT` to be free, start it with `wt dev`, then check that the app responds on `WC_PORT`

## Prototypes

- Throwaway UI prototypes go in `dev/prototypes/<name>.ex` as module `WatchClubWeb.Prototypes.<Name>`, and the dev server shows each one at `/dev/prototypes/<name>`
- Git ignores this folder. A new worktree gets a copy of the primary worktree's prototypes, and `wt remove` or `wt merge` copies its new and changed ones back to the primary worktree. Worktrees that already exist never get them
- Never put prototypes in `lib/` or any other tracked file

## Tidewave

The `tidewave-mcp` server gives access to the running dev server. Prefer its tools to the shell:
- `project_eval` runs Elixir code in the running app, instead of `mix run` or a new `iex`
- `execute_sql_query` queries the dev database, instead of `psql`
- `get_logs` reads the server logs
- `get_source_location` finds where a module or function is defined

Every tool takes a `port`: use `WC_PORT` from `.env`. The tools only work while the dev server is running.

## i18n

- We use Gettext for internationalization. The app is currently translated in English (default) and French
- Comment messages with `# AI-translated (Claude)` when translating in the .po files
- Translate whole sentences, never parts of sentences, because word order changes between languages. When a sentence contains components (links, user names...), put them in placeholders with `gtcomponent/1` and render the result with `raw/1`: `raw(dgettext("feed", "%{user} joined the club", user: gtcomponent(user_ref(%{user: user}))))`

## Coding style

### Frontend

- Inline the CSS styles directly in the HEEX templates. Do not extract them to elixir functions, this makes the code harder to read and comprehend. If you find yourself duplicating them, it is often a sign that you need to extract a function component.
- Use tailwind classes based on semantic tokens from our design system as defined in `@docs/design-system/foundation.md`
- Use the UI primitives in `lib/watch_club_web/components/ui/` instead of raw styling when one exists, and reuse the shared components in `lib/watch_club_web/components/`
- Avoid long list of assigns in live views / live components. Prefer deriving data directly at the call site inline inside the component. When in need of many related assigns, consider creating a struct or Ash Resource for managing them. Try to extract business logic inside testable Ash resources.
- Make sure to always make UI responsive. Use Tailwind container queries rather than absolute breakpoints. Viewport units such as `svh` and capability queries such as `@media (hover: hover)` are fine.
- Prefer simpler `flex` layouts instead of `grid` when possible.
- A class you pass to a UI primitive doesn't override the primitive's own class for the same property, because the order in the CSS decides, not the order in `class`. Add a trailing `!` to make it win, such as `text-danger!`, as `components/ui/segmented_control.ex` does.
- Name and place LiveViews, LiveComponents and function components as `docs/web-layer.md` describes. It overrides the Phoenix usage rules on LiveView names and on when to use LiveComponents.
- Use LiveView streams for unbounded or large collections. Plain list assigns are fine for small, bounded ones, such as club memberships, invitations, club libraries and navigation lists: add a comment next to them saying the collection is intentionally small. This overrides the Phoenix usage rule to always use streams.

### Data Loading

- When loading data to display in pages that shouldn't fail (no user input), prefer ! bang version instead of handling error explicitely
- When loading data based on user input (form, url params, ...), errors are expected and you must handle them
- When submitting form, always handle the error case and update the form in the assigns
- When submitting actions that shouldn't fail (gated by UX), or very low chances with no possible mitigation, prefer ! bang versions.

### Backend

- Only add policies and Ash authorizers to resources when it adds meaningful value. Policies like "any logged in user can do any action" does not bring value.
- Do not use Ecto concepts directly, use Ash.
- Prefer built-in policy checks, such as `relates_to_actor_via(:owner)`, to custom check modules.
- Prefer the `defaults` shorthand to an explicit action block when the action has no extra logic.
- Name relationships by their role, such as `owner` rather than `user`.
- Never name a resource after an Elixir standard library module, because aliasing it shadows that module. That's why the list resource is `WatchClub.Lists.ContentList`.
- Reuse shared helpers, such as `WatchClub.Shared.LucideIcon.names/0`, instead of copying them per domain.
- User-facing fields get explicit validations with localized messages, as in `WatchClub.Clubs.Club`. These validations own the shape rules, so don't repeat min, max or format as attribute or argument constraints. Keep `allow_nil? false` when it is the persistence or input contract, with a comment saying the validations own the user-facing message. Internal data can rely on constraints alone. This overrides the Ash usage rule against validations that repeat constraints.
- Users never see a framework's generic error message. Give identities a localized `message` too. For a framework error without a message option, map it to a localized message in the form's `transform_errors`, as `lib/watch_club_web/live/accounts/sign_in_page.ex` does. Don't translate Ash's built-in messages with `mix ash.gen.gettext` instead.

## Coding guidelines

- Focus on readability and maintainability of the code and clear separation of concerns.
- Ash resources are the main module boundary. Business logic belongs in their actions, behind code interfaces, not in LiveViews or components.
- Don't code defensively, follow Elixir's mantra and "let it crash". Only handle "expected" errors explicitely
- Name every function that raises on failure with a trailing `!`, even when it has no non-raising version. Fix old functions that don't, rather than copying them.
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
- To check a LiveView end to end, write a throwaway test outside the repo, run it with `mix test /absolute/path.exs`, and don't commit it. Use `WatchClubWeb.ConnCase, async: false` and `import WatchClub.Generator`. Seed an administrator first with `generate(administrator())`, or every request redirects to `/setup`. To log in a seeded user, give it a token with `{:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)` and `Ash.Resource.put_metadata(user, :token, token)`, then `conn |> Plug.Test.init_test_session(%{}) |> AshAuthentication.Plug.Helpers.store_in_session(user)`.


## Documentation

- Comments and docs should be concise and only document the current state of the code. Conversation details or changes compared to past implementations should not be reflected in documentation.

## Pull requests

- PR titles follow Conventional Commits (`fix: …`, `feat(player): …`), because release-please builds versions and the changelog from them. See `CONTRIBUTING.md`
- Before handing a change over for review, run `mix precommit`: it compiles with warnings as errors, unlocks unused dependencies, formats the code and runs the tests
- `mix ci` runs every check CI runs

<!-- usage-rules-start -->
<!-- usage_rules-start -->
## usage_rules usage
_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->
