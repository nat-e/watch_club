# Watch Club Design System Foundation

## Direction

Watch Club uses the **Velvet Club** direction:

- Dark-only UI
- Cozy club + modern product feel
- Purple/aubergine foundation
- Dracula-inspired accents, not a Dracula clone
- Comfortable rounded shapes
- Readable contrast over visual drama

## Token principles

- Tokens name **meaning**, not color values.
- Keep the v0 token set small.
- Add a token only when the same meaning repeats across multiple components.
- Do not add component-specific tokens until semantic tokens are insufficient.
- Neutral surfaces share one text hierarchy.
- Strong fills use paired `on-*` foreground tokens.
- Primitive scales define raw values; semantic tokens alias those primitives; UI primitives consume semantic tokens; product code composes UI primitives.

## Tailwind mapping

Design-system notation uses dots for readability. Tailwind utilities use hyphenated aliases.

| Design token | CSS variable | Tailwind utility examples |
| --- | --- | --- |
| `color.canvas` | `--color-canvas` | `bg-canvas` |
| `color.surface` | `--color-surface` | `bg-surface` |
| `color.text-muted` | `--color-text-muted` | `text-text-muted` |
| `color.border-focus` | `--color-border-focus` | `border-border-focus` |
| `radius.card` | `--radius-card` | `rounded-card` |
| `shadow.card` | `--shadow-card` | `shadow-card` |

Watch Club source variables may use a project prefix internally, e.g. `--wc-color-surface`, then map into Tailwind `@theme` aliases.

## Color tokens

### Surfaces

| Token | Meaning |
| --- | --- |
| `color.canvas` | App/page canvas |
| `color.scrim` | Modal/sidebar backdrop scrim |
| `color.surface` | Default card or panel surface |
| `color.surface-raised` | Interactive or visually lifted neutral surface |
| `color.surface-inset` | Recessed surface inside a parent, such as inputs/search/code |
| `color.surface-overlay` | Floating surface for dialogs, popovers, dropdowns |
| `color.surface-hover` | Shared hover state for neutral interactive surfaces |
| `color.surface-active` | Shared pressed state for neutral interactive surfaces |
| `color.surface-selected` | Selected neutral surface, such as active nav, the current item of a segmented control, or a selected card |

Higher layers are lighter: `canvas` < `surface` < `surface-raised` = `surface-overlay`. `surface-inset` sits at canvas level, below the surface around it. Hover, pressed and selected each step lighter than every surface they appear on, in that order.

### Text

| Token | Meaning |
| --- | --- |
| `color.text` | Primary readable text |
| `color.text-muted` | Secondary text: descriptions, metadata, helper copy |
| `color.text-subtle` | Low-emphasis text: timestamps, placeholders, quiet hints |
| `color.text-disabled` | Disabled or unavailable text |

`text`, `text-muted` and `text-subtle` clear 4.5:1 on every neutral surface, `surface-selected` included.

Inverse text is not part of v0. If needed later, add `color.surface-inverse` and `color.text-inverse` together.

### Borders and focus

| Token | Meaning |
| --- | --- |
| `color.border` | Default visible border |
| `color.border-subtle` | Low-emphasis structural border/divider |
| `color.border-control` | Boundary that is the only sign of a control: inputs, selects, checkboxes, radios, segmented controls, selectable cards. Clears 3:1 on every surface up to hover |
| `color.border-focus` | Focus outline and focused input border |
| `color.focus-ring` | Solid halo around a focused control's border |

`border` and `border-subtle` are decorative. Buttons, cards and menus can use them because their text or background already identifies them.

Focus rules:

- `base.css` gives every `:focus-visible` element a solid 2px `border-focus` outline with a 2px gap. It clears 3:1 on every surface and fill, so buttons and links need nothing more.
- Bordered controls (inputs, selects, checkboxes, radios) draw their own focus instead: `outline-none focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-focus-ring`. The border carries the contrast; the halo only softens it.
- Never remove the outline without one of these. Inside a container that clips its children (`overflow-*`), keep the outline inside with `focus-visible:-outline-offset-2`.

### Fills

All semantic fills use the same token API. Valid fill names are `primary`, `accent`, `danger`, `success`, `warning`, and `info`.

| Token pattern | Meaning |
| --- | --- |
| `color.<fill>` | Strong fill color or tinted-surface foreground |
| `color.<fill>-hover` | Hover state for strong fills |
| `color.<fill>-active` | Pressed state for strong fills |
| `color.<fill>-bg` | Tinted background for callouts, badges, and quiet fill-related controls |
| `color.<fill>-border` | Border for tinted fill surfaces and fill-related invalid/focus states |
| `color.<fill>-ring` | Solid halo for fill-related focus or invalid states: the fill's 800 shade |
| `color.on-<fill>` | Foreground on strong fills |

Fill usage rules:

- Strong fills use `bg-<fill> text-on-<fill> hover:bg-<fill>-hover active:bg-<fill>-active`.
- Tinted fill surfaces use `border-<fill>-border bg-<fill>-bg text-<fill>`.
- Only primary actions get a strong fill, usually one per screen, plus `danger` inside a confirmation dialog. Accent buttons and badges are tinted or neutral, never strong fills, so they don't compete with it.
- Fill-related focus or invalid rings use `ring-<fill>-ring`.
- Do not derive fill states with opacity utilities such as `bg-danger/10` or `ring-danger/30`.

### Color roles

A starting point for choosing between pink, purple and neutral, not a strict rule: when a case doesn't fit, pick what reads best and use it the same way on every page. Each color has one job, and contrast, not hue, sets how much attention something gets: a strong fill is the main action, a tint is quiet.

| Color | Job | Examples |
| --- | --- | --- |
| `primary` (pink) | What people act on or turn on | The strong fill for the main action, such as Play. The tint for selected controls, such as filter chips and search scopes |
| `accent` (purple) | What the app points out | Unread counts, New badges, the highlight on something that just arrived |
| Neutral (`surface-selected`) | Where people are | The current page in navigation, the current item of a segmented control |

A selected chip shows its state with its tint alone, without a check mark: its fill sets it apart from the outlined chips around it.

## Non-color tokens

### Radius

| Token | Meaning |
| --- | --- |
| `radius.control` | Controls and small surfaces: buttons, inputs, selects, menus, tooltips, alerts, toasts |
| `radius.card` | Cards, panels, tables, dialogs, empty states |
| `radius.full` | Badges, avatars, pills |

Media components own their radius (posters, stills), like they own their sizes.

### Size

Size tokens cover repeated, non-content dimensions. Prefer them over raw Tailwind numbers for icons, controls, touch targets, and repeated row/header heights.

| Token | CSS variable | Tailwind utility examples | Meaning |
| --- | --- | --- | --- |
| `size.control-sm` | `--wc-size-control-sm` | `h-control-sm`, `size-control-sm` | Compact controls |
| `size.control-md` | `--wc-size-control-md` | `h-control-md`, `size-control-md` | Default controls |
| `size.control-lg` | `--wc-size-control-lg` | `h-control-lg`, `size-control-lg` | Large/auth/mobile controls |
| `size.icon-sm` | `--wc-size-icon-sm` | `size-icon-sm` | Dense/supporting icons |
| `size.icon` | `--wc-size-icon` | `size-icon` | Default app icon size |
| `size.icon-lg` | `--wc-size-icon-lg` | `size-icon-lg` | Prominent/mobile/nav icons |
| `size.icon-xl` | `--wc-size-icon-xl` | `size-icon-xl` | Extra-prominent icons in callouts or empty states |
| `size.touch-target` | `--wc-size-touch-target` | `min-h-touch-target`, `size-touch-target` | Minimum interactive target for nav/list/icon rows |
| `size.row-lg` | `--wc-size-row-lg` | `h-row-lg`, `min-h-row-lg` | App bars, overlay headers, and roomy selectable rows |

Size usage rules:

- Omit icon sizes inside UI primitives when the primitive already owns icon sizing.
- Use `size-icon-sm`, `size-icon`, `size-icon-lg`, or `size-icon-xl` instead of raw `size-4`, `size-5`, `size-6`, or `size-8` on standalone icons.
- Use `min-h-touch-target` instead of raw minimum row heights for interactive rows.
- Use `h-row-lg` or `min-h-row-lg` instead of raw `h-16` for repeated app bars, overlay headers, and large selectable rows.
- Keep content-specific media dimensions, such as poster widths, in the media component API instead of adding global size tokens.

### Spacing

Spacing tokens name the relationship created by empty space. Prefer these tokens over raw Tailwind values in product screens.

| Token | CSS variable | Tailwind utility examples | Meaning |
| --- | --- | --- | --- |
| `space.tight` | `--wc-space-tight` | `gap-tight`, `p-tight` | Dense spacing inside small component parts, such as icon/text pairs |
| `space.related` | `--wc-space-related` | `gap-related`, `p-related` | Closely related elements, such as label/helper text or repeated controls |
| `space.group` | `--wc-space-group` | `gap-group`, `p-group` | Default card/form grouping and medium component padding |
| `space.cluster` | `--wc-space-cluster` | `gap-cluster`, `p-cluster` | Subsections inside a surface or modal |
| `space.section` | `--wc-space-section` | `gap-section`, `py-section` | Major page sections |
| `space.page` | `--wc-space-page` | `px-page` | Responsive horizontal page gutter |
| `space.page-y` | `--wc-space-page-y` | `py-page-y` | Responsive vertical page gutter |

### Layout

| Token | CSS variable | Tailwind utility examples | Meaning |
| --- | --- | --- | --- |
| `layout.readable` | `--wc-layout-readable` | `max-w-readable` | Line length for paragraphs: 34em, about 45–75 characters. In `em`, so it follows the text size |
| `layout.panel` | `--wc-layout-panel` | `max-w-panel` | Forms, settings panels, and focused workflows |
| `layout.page` | `--wc-layout-page` | `max-w-layout-page` | Standard page content width |

Validated layout primitives:

| Primitive | Meaning |
| --- | --- |
| `<.page>` | Responsive page gutters, page max-width, and default page rhythm |
| `<.section>` | Carded semantic content section with optional title, icon, description, and action |
| `<.stack>` | Vertical rhythm between related children |
| `<.inline>` | Single-line horizontal rhythm |
| `<.cluster>` | Wrapping horizontal rhythm, such as badges and action groups |
| `<.card>` | Lower-level surface primitive: radius, border, padding, and elevation |

### Forms

Forms use two validated primitives before adding larger layout components:

| Primitive | Meaning |
| --- | --- |
| `<.form>` | Watch Club wrapper around `Phoenix.Component.form/1`; default field rhythm is `gap-cluster` and actions render through `<:action>` |
| `<.field>` | Replaces `<.input_with_label>`; owns label, control, hint, and error rhythm |

Form spacing rules:

| Relationship | Token |
| --- | --- |
| Label to control | `space.related` |
| Control to hint or error | `space.tight` or `space.related` |
| Field to field | `space.cluster` via the form wrapper |
| Action to action | `space.related` |

Use `layout="none"` for forms that are already custom layouts, such as search bars and full-screen overlays.

Defer `<.form_group>`, `<.form_section>`, and `<.fieldset>` until repeated screens prove those meanings.

### Shadow

Pick a shadow by how high the element sits above the page, not by how it looks. On a dark UI shadows barely show, so lighter surfaces carry most of the depth.

| Token | Meaning |
| --- | --- |
| `shadow.card` | Cards and panels resting on the page |
| `shadow.overlay` | Floating menus, popovers, tooltips, and toasts |
| `shadow.modal` | Dialogs, the highest layer |
| `shadow.glow` | Rare brand glow for primary emphasis |

### Typography

| Font | CSS variable | Use |
| --- | --- | --- |
| Reddit Sans | `--font-sans` | Body and UI text |
| Oxanium | `--font-heading` | Page and section titles |
| Fira Code | `--font-mono` | Code and invitation codes |

Typography rules:

- Two weights: `font-normal` (400) for text, `font-semibold` (600) for emphasis — headings, buttons, labels, the main text of a row. They are the only weights loaded, so others fall back to them. To de-emphasize, use a lighter color or a smaller size, not a lighter weight.
- Sizes come from Tailwind's scale only, `text-xs` (12px) to `text-7xl` (72px). No `em` font sizes: `em` compounds through nesting and leaves the scale. The only arbitrary size is the overflow count in the smallest avatar group.
- Keep each size's built-in line height: it already gets tighter as text gets bigger. Long paragraphs may use `leading-relaxed`.
- Paragraphs stop at `max-w-readable`.
- All-caps text uses `tracking-wider` (0.05em). Headings set in the body font may use `tracking-tight`. Everything else keeps the font's own spacing.

### Opacity

Translucency is only for overlays on images and video, scrims, and disabled states. Use these steps only: `10`, `20`, `40`, `60`, `80`, `90` (`bg-black/60`, `opacity-40`). Disabled controls use `opacity-40`. To make a token color lighter or darker, pick another shade from its ramp instead.

## Design rules

The tokens can't enforce these rules from *Refactoring UI*, by Adam Wathan and Steve Schoger.

- **Importance:** show it with weight and color before size (`text`, `text-muted`, `text-subtle`, `font-semibold`), and tone down what competes instead of making the main thing louder.
- **Icons:** an icon next to text gets a quieter color than the text, such as `text-muted`, because icons look heavier than letters.
- **Headings:** the tag follows the page structure and the size follows importance, so a section title can be an `h2` at `text-base`.
- **Labels:** skip `label: value` when the format or context already says what the data is, like a release year, and fold a needed label into the value ("12 episodes").
- **Buttons:** one `primary` button per screen, `secondary` or `accent` for secondary actions, `ghost` for minor ones, and `danger` only for the confirm button of a destructive dialog.
- **Color:** never show meaning with color alone; add an icon, a label or a shape.
- **Spacing:** leave more space around a group than inside it.
- **Widths:** sidebars, panels and dialogs get a fixed width or a `max-w-*` so they stop growing; only the main area flexes.
- **Small screens:** big text shrinks more than small text, so drop a heading a size or two on phones (`text-3xl sm:text-4xl`) and keep body text about the same.
- **Borders:** separate things with space, a surface change or a shadow before reaching for a border, and use `border-subtle` for the dividers you keep.
- **Images:** posters and artwork sit in a fixed frame with `object-cover`, as `<.tmdb_poster>` does.
- **Icon size:** keep icons near their drawn size (`size-icon*`), and put a bigger one inside a shape instead of scaling it up.
- **Empty states:** use `<.empty>` with an icon, a title, a short explanation and the next action.

## Component strategy

- Build `WatchClubWeb.UI` primitives on top of these tokens.
- Feature code should use Watch Club UI primitives instead of raw styling when a primitive exists.
- Tokens are allowed in UI primitive implementations.
- Product/domain components should compose UI primitives.

Initial UI primitive order:

1. Button
2. Form/Field/Input
3. Card
4. Badge
5. Alert
6. Dialog/Modal

## Migration rule

New or migrated screens should use Watch Club UI primitives. Migrate one component family or screen at a time.
