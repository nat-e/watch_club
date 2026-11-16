---
name: typescript
description: "Write TypeScript in this app following the Google TypeScript Style Guide. Use before writing or changing TypeScript."
---

Follow the Google TypeScript Style Guide, `google-typescript-style-guide.md`. Biome checks every rule it can, including our own rules in `biome-plugins/`. This skill lists only our departures from Google and the rules no tool checks. Search the guide for cases this skill doesn't cover.

Fix what `pnpm check` reports. Silence a rule only for a reason Biome can't see, and give that reason in the `biome-ignore` comment:

- an `as` assertion: why it's safe
- a snake_case property: the API field or URL parameter it mirrors

Where we depart from Google:

- Import the app's own code through `@/`, as shadcn sets up, rather than relative paths
- Names may start or end with `_`, such as an unused parameter
- A `switch` over every member of a union has no `default`: `useExhaustiveSwitchCases` reports a missing case

Rules no tool checks:

- **Names**: spell words out (`errorCount`, not `errCnt`); use single letters only in scopes of 10 lines or fewer. Keep types out of names (`UserInterface`, `opt_`). Use CONSTANT_CASE for module-level values that never change and for `static readonly` fields
- **Imports and exports**: export only what other modules use. Import a few symbols by name, and use `import * as name` for many symbols of a large API
- **Types**: annotate a structural value where it's declared (`const user: User = {…}`). Use the simplest construct: extend an interface rather than use `Pick`, mapped types or conditional types. Name the key of an index signature (`{[userId: string]: User}`), or use a `Map`. No type parameter used only in the return type. Leave out annotations the compiler easily infers, and add them to empty containers (`new Map<string, User>()`)
- **Functions**: pass a callback through an arrow (`ids.map(id => parseId(id))`) unless the function was written as a callback. Use a concise arrow body only when its value is used. Keep default parameters simple, and use an options object for more than a few optional parameters. Label unclear literal arguments: `render(/* animate= */ true)`
- **Values**: spread only plain objects into objects. Don't mix quoted and unquoted keys in one object. Compare enum values explicitly, never as booleans. Check for `NaN` after `Number()`
- **Classes**: use parameter properties rather than copying constructor arguments, and initialize fields where they're declared. Keep getters pure. Prefer module functions to private static methods
- **Errors**: report failure by throwing, with an `Error` subclass when callers need to tell failures apart. In a `catch`, treat the value as an `Error`, and handle other values only for a named API that throws them. Keep `try` blocks to the calls that can throw
- **Comments**: use `/** */` for caller documentation and `//` for implementation comments; write a long implementation comment as several `//` lines. Document every member whose name isn't enough and every export except those only tools read, such as a route's `Route`. Start JSDoc with a third-person verb ("Returns the…") for functions other than components, a noun phrase ("A labelled text input…", "The messages…") for components, types, constants and properties, or "Whether" for booleans: a component is something on screen, not an action. Start no JSDoc with "What", "How", "Why" or "Who", and no comment with "Where". Don't restate the name or type. `@deprecated` says what to use instead
- **Directives**: no `@ts-expect-error` or `@ts-nocheck` outside tests, and no `/// <reference>` outside generated files
