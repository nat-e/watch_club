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
| `color.surface-selected` | Selected neutral surface, such as active nav/filter/card |

### Text

| Token | Meaning |
| --- | --- |
| `color.text` | Primary readable text |
| `color.text-muted` | Secondary text: descriptions, metadata, helper copy |
| `color.text-subtle` | Low-emphasis text: timestamps, placeholders, quiet hints |
| `color.text-disabled` | Disabled or unavailable text |

Inverse text is not part of v0. If needed later, add `color.surface-inverse` and `color.text-inverse` together.

### Borders and focus

| Token | Meaning |
| --- | --- |
| `color.border` | Default visible border |
| `color.border-subtle` | Low-emphasis structural border/divider |
| `color.border-strong` | High-emphasis neutral border |
| `color.border-focus` | Focus and focused input border |
| `color.focus-ring` | Neutral focus ring |

### Fills

All semantic fills use the same token API. Valid fill names are `primary`, `accent`, `danger`, `success`, `warning`, and `info`.

| Token pattern | Meaning |
| --- | --- |
| `color.<fill>` | Strong fill color or tinted-surface foreground |
| `color.<fill>-hover` | Hover state for strong fills |
| `color.<fill>-active` | Pressed state for strong fills |
| `color.<fill>-bg` | Tinted background for callouts, badges, and quiet fill-related controls |
| `color.<fill>-border` | Border for tinted fill surfaces and fill-related invalid/focus states |
| `color.<fill>-ring` | Ring color for fill-related focus or invalid states |
| `color.on-<fill>` | Foreground on strong fills |

Fill usage rules:

- Strong fills use `bg-<fill> text-on-<fill> hover:bg-<fill>-hover active:bg-<fill>-active`.
- Tinted fill surfaces use `border-<fill>-border bg-<fill>-bg text-<fill>`.
- Fill-related focus or invalid rings use `ring-<fill>-ring`.
- Do not derive fill states with opacity utilities such as `bg-danger/10` or `ring-danger/30`.

## Non-color tokens

### Radius

| Token | Meaning |
| --- | --- |
| `radius.control` | Buttons, inputs, select triggers |
| `radius.card` | Cards, panels, recommendation cards |
| `radius.full` | Badges, avatars, pills |

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
| `layout.readable` | `--wc-layout-readable` | `max-w-readable` | Long-form readable content width |
| `layout.panel` | `--wc-layout-panel` | `max-w-panel` | Forms, settings panels, and focused workflows |
| `layout.page` | `--wc-layout-page` | `max-w-layout-page` | Standard page content width |

Validated layout primitives:

| Primitive | Meaning |
| --- | --- |
| `<.page>` | Responsive page gutters, page max-width, and default page rhythm |
| `<.section>` | Major content section with semantic vertical rhythm |
| `<.stack>` | Vertical rhythm between related children |
| `<.inline>` | Single-line horizontal rhythm |
| `<.cluster>` | Wrapping horizontal rhythm, such as badges and action groups |
| `<.card>` | Standard surface, radius, border, padding, and elevation |

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

| Token | Meaning |
| --- | --- |
| `shadow.card` | Default card/panel elevation |
| `shadow.overlay` | Dialog/dropdown/popover elevation |
| `shadow.glow` | Rare brand glow for primary emphasis |

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
