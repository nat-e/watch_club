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

### Actions

| Token | Meaning |
| --- | --- |
| `color.primary` | Main Watch Club action fill |
| `color.primary-hover` | Hover state for primary actions |
| `color.primary-active` | Pressed state for primary actions |
| `color.on-primary` | Foreground on primary fills |
| `color.accent` | Expressive pink accent for rare emphasis |
| `color.on-accent` | Foreground on accent fills |
| `color.danger` | Destructive action/error color |
| `color.on-danger` | Foreground on danger fills |

### Status

| Token | Meaning |
| --- | --- |
| `color.success` | Success foreground |
| `color.success-bg` | Success tinted background |
| `color.success-border` | Success border |
| `color.warning` | Warning foreground |
| `color.warning-bg` | Warning tinted background |
| `color.warning-border` | Warning border |
| `color.info` | Information foreground |
| `color.info-bg` | Information tinted background |
| `color.info-border` | Information border |
| `color.danger-bg` | Danger tinted background |
| `color.danger-border` | Danger border |

## Non-color tokens

### Radius

| Token | Meaning |
| --- | --- |
| `radius.control` | Buttons, inputs, select triggers |
| `radius.card` | Cards, panels, recommendation cards |
| `radius.full` | Badges, avatars, pills |

### Size

| Token | Meaning |
| --- | --- |
| `size.control-sm` | Compact controls |
| `size.control-md` | Default controls |
| `size.control-lg` | Large/auth/mobile controls |
| `size.icon` | Default icon size |

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
2. Card
3. Field/Input
4. Badge
5. Alert
6. Dialog/Modal

## Migration rule

New or migrated screens should use Watch Club UI primitives. Migrate one component family or screen at a time.
