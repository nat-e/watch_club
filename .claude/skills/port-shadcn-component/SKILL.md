---
name: port-shadcn-component
description: Port a React Shadcn UI component into the Phoenix LiveView UI library at `lib/watch_club_web/components/ui/`.
---

# Port a shadcn component

Each component is two colocated files: `<name>.ex` (structure) and `<name>.css` (styles). The `class` prop passes through user overrides; component identity, variants, and state live on `data-*` attributes. Reference: [alert.ex](lib/watch_club_web/components/ui/alert.ex) and [alert.css](lib/watch_club_web/components/ui/alert.css).

# Philosophy

The goal is to provide the same styling, functionalities and a similar API to Radix based Shadcn React components for Phoenix LiveView but the architecture and philosophy is different.

## Limitations

- We do not intend to support RTL

## Slots for sub-components

- We prefer using slots inside the main component rather than multiple components when nesting. For example, in `alert.ex`, we declare a `<:title>` slot for rendering the title, instead of declaring a `<.alert_title>` component. This enforces that sub-components cannot be used outside of their parent, and creates a more straight forward API.
- If there is an obvious "content" children, it will be declared with the `inner_block` slot. The others will be using named slots.
- When it makes sense, we try to declare a `class` attribute for the named slots, to allow for straight forward callsite customization.

## CSS layers for styling with tailwind

- We use CSS layers for handling base styles, variants and user overrides instead of `tailwind-merge` / `tailwind-variants` type of utility. `tails`, `twix` and many other have tried and gave up. We believe this requires too much maintenance to keep up with Tailwind updates. We use CSS layer as follows:

  - `base`: base styling for the app
  - `components`: styling for our UI components.
    - `components.base` for the base styling of the component (what is in Shadcn's `tv.base`)
    - `components.variants` for the variant specific styles (what is in Shadcn's `tv.variants`)
  - `utility`: styling for the screens and other components, inlined in `class`. Allows overriding the `components` styles

- Components are split between a `<name>.ex` and a `<name>.css`, located in `lib/watch_club_web/components/ui`

- We use data-attributes for applying selectors to our components: `data-slot="<name>"` instead of `data-slot` for the component and `data-variant="<variant_name>` for the variant.

- All the styling in the `*.css` files is done with Tailwind utility classes via `@apply`

- `group/<name>` statements are not supported by Tailwind v4. They should be moved to the class decalaration in the component file: `class={["group/<name>", @class]}`

- Do not split long CSS statements into multiple @apply for readability. While this improves the readability of the code, this makes updating components easier. Stick to one CSS line per subcomponent variant.

### Example

```typescript
const buttonVariants = cva(
  "group/button inline-flex shrink-0 items-center justify-center rounded-md border border-transparent bg-clip-padding text-sm font-medium whitespace-nowrap transition-all outline-none select-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 active:not-aria-[haspopup]:translate-y-px disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/80",
        outline:
          "border-border bg-background shadow-xs hover:bg-muted hover:text-foreground aria-expanded:bg-muted aria-expanded:text-foreground dark:border-input dark:bg-input/30 dark:hover:bg-input/50",
        secondary:
          "bg-secondary text-secondary-foreground hover:bg-secondary/80 aria-expanded:bg-secondary aria-expanded:text-secondary-foreground"
      },
      size: {
        default:
          "h-9 gap-1.5 px-2.5 in-data-[slot=button-group]:rounded-md has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
        lg: "h-10 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-3 has-data-[icon=inline-start]:pl-3",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)
```
Will be translated to:
```css
@layer components.base {
	[data-slot="button"] {
		@apply inline-flex shrink-0 items-center justify-center rounded-md border border-transparent bg-clip-padding text-sm font-medium whitespace-nowrap transition-all outline-none select-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 active:not-aria-[haspopup]:translate-y-px disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4;
	}
}

@layer components.variants {
	[data-slot="button"] {
		&[data-variant="default"] {
			@apply bg-primary text-primary-foreground hover:bg-primary/80;
		}

		&[data-variant="outline"] {
			@apply border-border bg-background shadow-xs hover:bg-muted hover:text-foreground aria-expanded:bg-muted aria-expanded:text-foreground dark:border-input dark:bg-input/30 dark:hover:bg-input/50;
		}

		&[data-variant="secondary"] {
			@apply bg-secondary text-secondary-foreground hover:bg-secondary/80 aria-expanded:bg-secondary aria-expanded:text-secondary-foreground;
		}

		&[data-size="default"] {
			@apply h-9 gap-1.5 px-2.5 in-data-[slot=button-group]:rounded-md has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2;
		}

		&[data-size="lg"] {
			@apply h-10 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2;
		}
	}
}
```
And the button will contain `class={["group/button", @class]}`

## Source

Our styles are replicating the Radix Vega style for Shadcn v4 components.
Read the source component(s) at: `https://raw.githubusercontent.com/shadcn-ui/ui/refs/heads/main/apps/v4/styles/radix-vega/ui/<name>.tsx`

And its documentation at `https://ui.shadcn.com/docs/components/radix/<name>`

Read the source code of the Radix primitives that are involved:
`https://github.com/radix-ui/primitives/tree/main/packages/react/<primitive-name>`
And its documentation:
`https://www.radix-ui.com/primitives/docs/components/<primitive-name>`

When porting or updating a component, maintain the following moduledoc:

```elixir
@moduledoc """
<Concise description of the component: What it is and when to use>

<Usage example>

Ported from Shadcn on <date>
Commit: Hash of the commit
Source: <link of the source at this exact commit>
Doc: <link of the shadcn doc>
Radix doc: <link of the radix doc, if relevant>
"""
```

The source and hash of the commit can be used later to diff components and update them.


## Composing other UI components

When your component renders another (e.g., `<.button>`):

- **Explicit import** at the top of the module: `import Shadcn.Components.Button`
- **Style contextually** via descendant selectors in your CSS:

   ```css
   [data-slot="alert"] [data-slot="button"] {
     @apply translate-y-0.5;
   }
   ```

## Procedure

0. Read the source implementations and docs from Shadcn **and** Radix
1. Plan a design for the component. Your plan should be readable and concise and should contain:
  - Components and slots to be created
  - API for each component (variants, slots and attrs)
  - JS dynamic behavior
Wait until the design is validated by the user
2. Implement the components and their CSS
3. Add `@import "../../lib/watch_club_web/components/ui/<name>.css";` to [assets/css/components.css](assets/css/components.css). Keep alphabetically ordered.
3. (Optional) If adding an external JS file, import it in `assets/js/components.js`
4. Add `import Shadcn.Components.<Name>` to `__using__/1` in [lib/watch_club_web/ui.ex](lib/watch_club_web/ui.ex). Keep alphabetically ordered.
5. Run `mix compile --force`, `mix credo` and `biome lint` until clean. The `attr ... values:` validation surfaces stale call sites.
6. Add the component to Storybook (`storybook/ui/<name>.story.exs`). Re-create exactly the same variants that are displayed on the Shadcn document for that component at `https://ui.shadcn.com/docs/components/radix/<name>`
7. Use Playwright to make sure all variants of all components are working well in Storybook.\

## Rules

- Always list sizes by ascending order (ie, `sm default lg`, not `default sm lg` so that they display nicely in Storybook)

### Javascript

- Use `Phoenix.LiveView.ColocatedHook` for adding JS behavior if less than 10 lines. Otherwise, move to a `<name>.js` file so that we get biome linting and formatting.
- When interacting with data-attributes, use `this.el.getAttribute/this.el.setAttribute` to allow better grep support.
- If the hook caches references to descendant elements (`querySelector`) or attaches listeners to them, also implement `updated()` and re-run the same setup. Phoenix LiveView keeps the hooked root across morphs but can replace child elements when attrs change (e.g. Storybook playground), leaving stale references that report 0×0 rects or have lost their listeners. Factor the setup into one function and call it from both `mounted()` and `updated()`. If listeners might already be attached, remove from the previous reference before re-binding.
- Avoid transform-based entry animations (`slide-in-…`, `zoom-in-…`) on a container that holds nested `position: fixed` popovers / submenus. While the animation runs, the container has an active `transform`, which makes it a containing block for fixed descendants — so the descendant's viewport coordinates get scoped to the container's box and the popover flickers into the parent and snaps out when the animation ends. Use opacity-only entry animations on such containers, or portal the fixed descendant to `document.body`.

