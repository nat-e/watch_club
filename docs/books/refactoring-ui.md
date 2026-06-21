# Refactoring UI — Working Summary

A contributor-focused distillation of *Refactoring UI* by Adam Wathan and Steve
Schoger. The book is a catalogue of concrete, repeatable tactics for making
interfaces look designed — without "artistic talent." This summary keeps the
tactics and reframes them as guidance you can apply while building Watch Club
screens.

**How to read this doc.** Each section states the principle, then gives the
*tactic* (what to actually do) and, where relevant, a **Watch Club** note that
maps the idea to our design system (`docs/design-system/foundation.md`). When the
book's advice and our token system disagree, the token system wins — most of
these decisions are already baked into our tokens and primitives, so applying the
book usually means *reaching for the right token*, not inventing a new value.

The single biggest meta-lesson: **good UI comes from systems and hierarchy, not
from talent or superficial styling.** Almost everything below is an instance of
one of those two ideas.

---

## Table of contents

1. [Starting from scratch](#1-starting-from-scratch)
2. [Hierarchy is everything](#2-hierarchy-is-everything)
3. [Layout and spacing](#3-layout-and-spacing)
4. [Designing text](#4-designing-text)
5. [Working with color](#5-working-with-color)
6. [Creating depth](#6-creating-depth)
7. [Working with images](#7-working-with-images)
8. [Finishing touches](#8-finishing-touches)
9. [Leveling up](#9-leveling-up)
10. [Quick reference checklist](#10-quick-reference-checklist)
11. [How this maps to Watch Club](#11-how-this-maps-to-watch-club)

---

## 1. Starting from scratch

How to get moving on a new design without freezing up.

### Start with a feature, not a layout

Don't start by "designing the app" — the shell (nav bar, sidebar, logo
placement, container vs. full-width). You don't have enough information to make
those decisions yet, and starting there is the fastest route to feeling stuck.

**Tactic:** Start with one concrete piece of functionality. For a flight search,
that's the departure/destination fields, the dates, and the search button. An app
is a *collection of features*; design a few features first, and the shell's
requirements will reveal themselves.

**Watch Club:** When adding a screen, design the actual job first (e.g. "continue
watching a show", "add a title to the library") before worrying about how it
slots into navigation.

### Detail comes later

In the earliest stage, do **not** get hung up on typefaces, shadows, icons, or
color. They matter eventually, not now.

**Tactics:**
- Sketch low-fidelity. Jason Fried's trick: design on paper with a thick Sharpie
  so you *can't* obsess over detail.
- **Hold the color.** Design in grayscale first. It forces spacing, contrast, and
  size to carry the hierarchy. You end up with a clearer interface that's easy to
  enhance with color later.
- **Don't over-invest.** Sketches and wireframes are disposable. Use them to
  explore, then throw them away once you've decided.

### Don't design too much

Figuring out every feature and edge case up front, in the abstract, is brutally
hard ("How does this look with 2000 contacts? Where does the error go?").

**Tactics:**
- **Work in cycles.** Design a simple version of the next feature, *build the real
  thing*, then iterate on the working interface. It's far easier to fix design
  problems in something you can actually use than to imagine every edge case.
- **Be a pessimist.** Don't imply functionality you aren't ready to build. Design
  the smallest useful version you can ship. A comment system without attachments
  still beats no comment system — but if you designed attachments in from day one
  and they turn out to be hard, you've got nothing to ship. Build the simple
  version first; add the "nice-to-haves" later.

**Watch Club:** This matches our "let it crash" / ship-the-simple-version
mindset. Design the smallest useful slice, build it as a real Ash action +
LiveView, and iterate.

### Choose a personality

Personality feels abstract but comes from a few concrete levers:

- **Font choice.** Serif → elegant/classic. Rounded sans-serif → playful. Neutral
  sans-serif → plain, lets other elements carry personality.
- **Color.** Blue is safe and familiar. Gold reads expensive/sophisticated. Pink
  is fun and not-so-serious. Don't over-think the psychology — notice how colors
  *feel* to you.
- **Border radius.** Small radius is neutral. Large radius feels playful. No
  radius feels serious/formal. **Stay consistent** — mixing square and rounded
  corners in one UI almost always looks worse than committing to one.
- **Language.** Copy hugely shapes personality. Formal tone reads
  official/professional; casual tone reads friendly. Words are everywhere in a UI;
  choosing the right ones matters as much as color or type.

To decide a personality, look at the other sites your audience already uses and
match the register — but don't copy direct competitors or you'll look like a
second-rate clone.

**Watch Club:** Our personality is already chosen — "Velvet Club": dark-only,
cozy-club-meets-modern-product, purple/aubergine foundation, Dracula-inspired
accents, comfortable rounded shapes, readable contrast over visual drama. New work
should reinforce that, not drift from it. Radius is fixed by `radius.control`,
`radius.card`, `radius.full` — use them, don't hand-pick corner values.

### Limit your choices

Infinite options are a paralyzing curse, not a luxury. You can waste an afternoon
on "12px or 13px?", "10% or 15% opacity?", "medium or semibold?". When nothing is
clearly wrong, every decision is torture.

**Tactics:**
- **Define systems in advance.** Pick from a set of 8–10 shades, not the color
  picker. Use a predefined type scale, not pixel-by-pixel nudging.
- **Design by process of elimination.** With a constrained scale, guess a value,
  then compare the neighbors on each side. Usually two options are obviously bad,
  and the right one falls out. If an outer option wins, re-center on it and
  compare again.
- **Systematize everything:** font size, font weight, line height, color, margin,
  padding, width, height, box shadows, border radius, border width, opacity.
  You don't have to define it all up front — just approach design with a
  systems mindset and avoid making the same low-level decision twice.

**Watch Club:** This is the entire philosophy of our token set. Spacing, sizing,
color, radius, and shadow are *already* constrained systems. The book's "limit
your choices" is literally our token principle: "Add a token only when the same
meaning repeats." When you find yourself reaching for a raw Tailwind number
(`size-5`, `h-16`, `bg-danger/10`), that's the smell the book warns about — use
the token (`size-icon`, `h-row-lg`, `bg-danger-bg`) instead.

---

## 2. Hierarchy is everything

Visual hierarchy = how important elements appear relative to one another. It's the
single most effective tool for making something feel "designed." When everything
competes for attention, the UI feels noisy. Deliberately de-emphasize secondary
and tertiary content, highlight what matters, and the result is immediately better
— even with the same colors, fonts, and layout.

### Size isn't everything

Relying on font size alone for hierarchy gives you primary content that's too big
and secondary content that's too small.

**Tactics:**
- Use **font weight** and **color** to carry hierarchy, not just size. A bolder
  primary element can stay a reasonable size and still read as important. Softer
  *color* for supporting text beats a tiny font size (better readability).
- Stick to **two or three text colors:**
  - Dark for primary content (an article headline)
  - Grey for secondary content (a publish date)
  - Lighter grey for tertiary content (a footer copyright)
- Stick to **two font weights** for UI: normal (400–500) for most text, heavier
  (600–700) for emphasis.
- **Avoid weights under 400** for UI — too hard to read at small sizes. To
  de-emphasize, use a lighter *color* or smaller size, not a thinner weight.

**Watch Club:** Our text colors are exactly this ladder: `color.text` (primary),
`color.text-muted` (secondary: descriptions, metadata), `color.text-subtle`
(tertiary: timestamps, placeholders), plus `color.text-disabled`. Reach for these
four instead of inventing greys.

### Don't use grey text on colored backgrounds

Grey-on-white works because it's *reduced contrast*. On a colored background, grey
looks wrong. Reducing opacity on white text looks dull/washed-out (sometimes
"disabled"), and over an image the background bleeds through the text.

**Tactic:** Hand-pick a new color based on the background — same hue, adjust
saturation and lightness until it looks right. This reduces contrast without
looking faded.

**Watch Club:** This is why our strong fills ship paired `on-<fill>` tokens
(`color.on-primary`, etc.) instead of `text-white/70`. The foundation explicitly
forbids deriving fill states with opacity (`bg-danger/10`, `ring-danger/30`) —
use the hand-tuned `-bg`, `-border`, `-ring` tokens.

### Emphasize by de-emphasizing

Sometimes the main element won't stand out and there's nothing left to add to it.
Instead of pushing it harder, *de-emphasize what competes with it.*

**Tactics:**
- An active nav item not popping? Don't make it louder — make the *inactive* items
  softer so they recede.
- A sidebar competing with main content? Remove its background color and let
  content sit on the page background.

**Watch Club:** We have `color.surface-selected` for the active nav/filter/card and
the muted/subtle text ramp for everything else. Lean on the *quiet* tokens for the
non-active items rather than over-styling the active one.

### Labels are a last resort

When showing data (especially DB data), the naive `label: value` format gives
every field equal emphasis and kills hierarchy.

**Tactics:**
- **You might not need a label at all.** Format often tells you what something is:
  `janedoe@example.com` is an email, `(555) 765-4321` is a phone, `$19.99` is a
  price. Context does the rest ("Customer Support" under a name reads as
  department).
- **Combine labels and values.** "12 left in stock" beats "In stock: 12";
  "3 bedrooms" beats "Bedrooms: 3". One unit, easy to style meaningfully.
- **Labels are secondary.** When you *do* need a label (e.g. a scannable
  dashboard), treat it as supporting content: smaller, lower contrast, or lighter
  weight.
- **When to emphasize a label:** on information-dense pages where the user scans
  *for the label* (spec sheets — they look for "depth", not "7.6mm"). Then make
  the label darker and the value slightly lighter. Don't de-emphasize the data too
  much; it's still important.

### Separate visual hierarchy from document hierarchy

Semantic markup matters (`h1`–`h6`), but browsers default headings to
progressively smaller sizes, which tempts you into oversized titles. An `h1` of
"Manage Account" makes semantic sense but doesn't need to be big.

**Tactic:** Section titles often act like *labels* — supporting content. Usually
the section's content is the focus, so titles should often be small (sometimes
visually hidden but present for accessibility). **Pick elements for semantics;
style them for hierarchy.** Don't let the tag dictate the size.

### Balance weight and contrast

Bold text feels emphasized because it covers more surface area (more pixels per
unit space). That relationship generalizes:

- **Use contrast to compensate for weight.** Icons — especially solid ones — are
  visually heavy and steal emphasis from adjacent text. You can't change an icon's
  weight, so lower its contrast (softer color) as a counterbalance.
- **Use weight to compensate for contrast.** A thin 1px border can be too subtle
  in a soft color but too harsh when darkened. Make it slightly *heavier* (wider)
  to emphasize it while keeping the soft color.

**Watch Club:** Pair icons with `color.text-muted`/`text-subtle` next to primary
text so they don't dominate. Reach for `color.border-subtle` vs.
`color.border-strong` to tune emphasis without going harsh.

### Semantics are secondary (buttons)

Don't design actions purely by semantics. Every action sits in a pyramid of
importance: usually one true primary action, a couple of secondary, a few
tertiary.

**Tactics:**
- **Primary:** obvious — solid, high-contrast background.
- **Secondary:** clear but not prominent — outline or low-contrast background.
- **Tertiary:** discoverable but unobtrusive — style like a link.
- **Destructive ≠ big red bold by default.** If a destructive action isn't the
  page's primary action, give it a secondary/tertiary treatment. Save the big,
  red, bold styling for the *confirmation step*, where deleting genuinely *is* the
  primary action.

**Watch Club:** Map this onto our Button primitive variants and `danger` fill.
Most "delete" buttons in a list should be quiet; the destructive emphasis belongs
in the confirm dialog. (See the UI-kit gotcha memo: `data-modal-close` kills
`phx-submit` — keep the confirming submit button off the close path.)

---

## 3. Layout and spacing

### Start with too much white space

The easiest cleanup is giving every element more room to breathe. We don't do it
because on the web white space is *added* — you nudge margin up until it stops
looking actively bad, which yields the *minimum* breathing room, not a great one.

**Tactic:** Start with *too much* space and remove until you're happy. What looks
"a little too much" on a single element is usually "just enough" in a full UI.

**Dense UIs have their place** — dashboards that must show a lot at once. Just make
density a *deliberate* decision, not a default. It's more obvious when you need to
*remove* space than when you need to add it.

### Establish a spacing and sizing system

Don't nitpick 120px vs. 125px. Arbitrary one-pixel trialing is slow and produces
inconsistent designs.

**Tactics:**
- **A linear scale won't work.** "Everything is a multiple of 4px" doesn't help
  choose between 120 and 125. The system must account for *relative* difference:
  at the small end (icon size, button padding) a few pixels is huge (12→16px is
  +33%); at the large end (card width) it's imperceptible (500→520px is +4%).
- **Rule of thumb:** no two values in your scale should be closer than ~25%.
- **Build from a base:** start at 16px (divides nicely, default browser font
  size), then build with factors/multiples. Pack values tightly at the small end,
  spread them out as they grow.
- **Using the system** speeds you up dramatically (especially designing in the
  browser, where you type numbers) and adds subtle consistency.

**Watch Club:** Our spacing tokens already encode *relationships*, not raw px:
`space.tight`, `space.related`, `space.group`, `space.cluster`, `space.section`,
`space.page`/`space.page-y`. Pick by the relationship you want
("label-to-control" → `space.related`; "page section" → `space.section`), not by
counting pixels. Size tokens (`size.icon*`, `size.control-*`, `size.row-lg`,
`size.touch-target`) do the same for dimensions.

### You don't have to fill the whole screen

Big displays tempt you to fill 1200–1400px. Having the space doesn't mean using
it. If you only need 600px, use 600px — spreading things out makes a UI harder to
read, and edge breathing room never hurt.

**Tactics:**
- Don't make a section full-width just because the nav is full-width. Give each
  element only the space it needs.
- **Shrink the canvas.** Designing something small on a huge canvas is hard —
  shrink the canvas. Design the mobile (~400px) layout first, then expand to
  desktop; you'll change less than you expect.
- **Think in columns.** A narrow form that feels unbalanced on a wide screen?
  Don't widen it — split supporting text into a second column. Keeps the form's
  optimal width while filling space.
- **Don't force it** either way: if you need a lot of space, use it; just don't
  feel obligated to fill it.

**Watch Club:** Use `layout.readable` (long-form), `layout.panel` (forms/settings),
and `layout.page` (standard page) to cap width deliberately. The `<.page>`
primitive already owns responsive gutters and page max-width. Always design for
multiple viewports (per CLAUDE.md).

### Grids are overrated

A 12-column grid simplifies layout, but outsourcing *all* decisions to it does
harm.

**Tactics:**
- **Not all elements should be fluid.** A grid gives percentage widths; lots of
  things should be *fixed*. A sidebar at 25% gets too wide on large screens
  (wasting content space) and too narrow on small screens (awkward wrapping). Give
  the sidebar a *fixed* width tuned to its contents and let main content flex to
  fill the rest. Inside components too — don't use percentages unless you actually
  want scaling.
- **Don't shrink an element until you need to.** If 500px is the card's optimal
  width, don't let a fluid grid make it smaller while you have the space. Use
  `max-width` and only shrink when the screen is narrower than that.

**Watch Club:** CLAUDE.md says prefer simple `flex` layouts over `grid` when
possible — same lesson. Use fixed/`max-width` for elements with an optimal size
and let neighbors flex.

### Relative sizing doesn't scale

Tempting belief: if element A shrinks 25% on mobile, B should too. It's false.

**Tactics:**
- A 45px headline on an 18px body might be `2.5em`, but if body drops to 14px on
  mobile, `2.5em` = 35px — way too big. A good mobile headline is ~20–24px
  (~1.5–1.7× body), a *different* relationship. So there's no real fixed
  relationship to encode. **Large elements must shrink faster than small ones**;
  the gap between small and large should be less extreme on small screens.
- **Relationships within elements:** don't tie button padding to font size via
  `em`. Proportional scaling makes a big button look like a zoomed small button.
  Instead, let padding grow *disproportionately* generous at larger sizes and
  tighter at small sizes, so a large button feels genuinely larger.

**Watch Club:** This is why we have a hand-built type scale and discrete
`size.control-sm/md/lg` rather than `em`-derived sizing. Don't reintroduce `em`
chains.

### Avoid ambiguous spacing

When there's no border or background separating groups, spacing alone signals
grouping — and it's easy to get wrong. If the margin below a form label equals the
margin below its input, the label/input pair doesn't read as connected (users may
fill the wrong field).

**Tactic:** **Always make the space *around* a group larger than the space
*within* it.** Applies to form groups, space above section headings, bullet lists
(gap between bullets vs. line-height within a bullet), and horizontal layouts too.

**Watch Club:** Encoded directly in our form spacing rules — label→control is
`space.related`, field→field is `space.cluster` (larger). The `<.field>` and
`<.form>` primitives already enforce "more around than within." Trust them.

---

## 4. Designing text

### Establish a type scale

Most UIs use way too many sizes — often every pixel from 10–24px. That's
inconsistent and slow.

**Tactics:**
- **A linear scale won't work** (same reason as spacing). Small jumps matter at
  the bottom; you don't want to choose between 46 and 48px at the top.
- **Modular scales** (ratios like 4:5, 2:3, golden 1:1.618) are mathematically
  pretty but flawed for UI: they produce fractional values (subpixel rounding
  differs across browsers) and too few sizes (you'll wish for a value between 12
  and 16). Round them yourself if you use them.
- **Hand-crafted scales** are more practical for interfaces: pick whole-pixel
  values by hand, total control, no rounding errors.
- **Avoid `em` units for the scale.** Because `em` is relative to current font
  size, nested elements compute to sizes *not in your scale* (1.25em inside 1.25em
  = 17.5px, off-scale). Stick to `px` or `rem` to actually stay on the system.

### Use good fonts

Developing a typographic eye takes years; shortcuts:

- **Play it safe:** a neutral sans-serif (Helvetica-like), or the system font
  stack (`-apple-system, Segoe UI, Roboto, Noto Sans, Ubuntu, Cantarell, Helvetica
  Neue`). Users are used to it.
- **Ignore typefaces with fewer than five weights** — more weights usually means
  more care/craft. On Google Fonts, filtering to 10+ styles (weights × italics)
  cuts ~85% of options.
- **Optimize for legibility:** fonts are designed for a purpose. Headline fonts
  have tight letter-spacing and short x-heights; text fonts have wider spacing and
  taller x-heights. Avoid condensed/short-x-height faces for main UI text.
- **Trust the crowd:** popular fonts are usually good. Sort by popularity,
  especially when picking something with personality (a serif).
- **Steal from people who care:** inspect sites you admire and see what they use.

### Keep your line length in check

Don't fit text to the layout — fit it to readability. Usually that means lines
that are too long.

**Tactic:** Aim for **45–75 characters per line** (~20–35em width). Going a bit
past 75 can work but is risky; stick to the range to play safe. When mixing
paragraphs with wider components (images), still cap the *paragraph* width even if
the content area is wider.

**Watch Club:** `layout.readable` (`max-w-readable`) exists for exactly this.

### Baseline, not center

When mixing font sizes on one line (a large card title + smaller actions), don't
vertically center them — align by their **baseline** (the line letters rest on).
Centering offsets the baselines and looks awkward, especially when sizes are
close.

### Line-height is proportional

"~1.5 line-height" is a starting point, not a universal rule.

**Tactics:**
- **Account for line length:** wider paragraphs need taller line-height (up to ~2)
  so the eye finds the next line; narrow content can use ~1.5. Line-height and
  width are proportional.
- **Account for font size:** small text needs more line spacing; large headlines
  need little or none (line-height of 1 is fine). **Line-height and font size are
  *inversely* proportional** — taller for small text, shorter for large text.

### Text alignment

- **Align for readability:** match the language direction. For English, the vast
  majority of text is left-aligned.
- **Don't center long-form text.** Centering is fine for headlines or short
  independent blocks, but anything longer than 2–3 lines reads better
  left-aligned. If one of several centered blocks is too long, rewrite it shorter
  — fixes alignment *and* feels more consistent.
- **Right-align numbers** in tables so decimals line up and values compare at a
  glance.
- **Hyphenate justified text.** Justification looks formal but creates ugly word
  gaps without hyphenation. Use justify + hyphens together, mainly for
  print-like looks (online magazine). Left-aligned works fine there too.

### Not every link needs a color

A link in a block of plain text must stand out and look clickable. But in an
interface where *almost everything* is a link, the "pop" treatment is
overbearing.

**Tactic:** Emphasize most links subtly — heavier weight or darker color. Truly
ancillary links can have no default emphasis at all, only revealing an
underline/color *on hover*. Still discoverable, doesn't compete with important
actions.

### Use letter-spacing effectively

Generally trust the type designer and leave it alone. Two exceptions:

- **Tightening headlines:** a legibility-oriented family (Open Sans) has wider
  built-in spacing than a headline family (Oswald). For big headlines, *decrease*
  letter-spacing to mimic a condensed headline face. Don't try the reverse —
  headline fonts rarely work small even with extra spacing.
- **Improving all-caps legibility:** default spacing is tuned for sentence case
  (varied ascenders/descenders). All-caps letters are uniform height with fewer
  distinguishing features, so *increase* letter-spacing for all-caps text.

---

## 5. Working with color

### Ditch hex for HSL

Hex/RGB make visually-similar colors look unrelated in code. **HSL** uses
attributes the eye perceives:

- **Hue** — position on the color wheel, in degrees (0° red, 120° green, 240°
  blue). What makes two colors both "blue."
- **Saturation** — how vivid (0% grey, 100% intense). With 0% saturation, hue is
  irrelevant.
- **Lightness** — closeness to black/white (0% black, 100% white, 50% pure color).

**HSL ≠ HSB.** In HSB, 100% brightness is only white when saturation is 0%; at
100% saturation, 100% brightness = HSL's 100% saturation + 50% lightness. Design
tools favor HSB, but **browsers understand HSL** — use HSL for the web.

### You need more colors than you think

The "five perfect colors" from a palette generator can't build a real UI. You need
three categories, each with multiple shades:

- **Greys** — almost everything (text, backgrounds, panels, controls) is grey.
  Need **8–10 shades** (3–4 isn't enough; you'll want "darker than #2 but lighter
  than #3"). Avoid true black — start from very dark grey and step up to white.
- **Primary color(s)** — one or two brand colors for primary actions, active nav,
  etc. Need **5–10 shades**: ultra-light tints for alert backgrounds, dark shades
  for text.
- **Accent colors** — for semantic states and emphasis: red (destructive), yellow
  (warning), green (positive), plus eye-grabbing highlights (teal/pink). Multiple
  shades each, used sparingly. Categorization UIs (graph lines, calendar events,
  tags) may need even more. A complex UI can need ~10 colors × 5–10 shades.

### Define your shades up front

Don't generate shades on the fly with `lighten()`/`darken()` — that's how you get
35 near-identical blues. Define a fixed set.

**Process:**
1. **Choose the base color first** — the middle shade. For primary/accent, pick
   something that works as a button background. No magic "start at 50% lightness";
   trust your eyes.
2. **Find the edges** — pick darkest (usually text) and lightest (usually a tinted
   background) shades. An alert component uses both, so it's a good place to pick
   them. Match the base hue, adjust saturation/lightness.
3. **Fill the gaps** — use 5, ideally ~9 shades (easy to divide). Call darkest
   900, base 500, lightest 100. Pick 700 and 300 (mid-gaps), then fill 800/600/
   400/200 the same way.
4. **Greys:** same process; base color matters less. Darkest = darkest text,
   lightest = subtle off-white background.
5. **It's not a science.** The systematic approach starts you off; tweak by eye
   when real usage demands it. But **add new shades rarely** — undisciplined
   palette growth means you have no system at all.

### Don't let lightness kill your saturation

In HSL, saturation's impact weakens as lightness approaches 0% or 100% — the same
saturation looks more colorful at 50% lightness than at 90%. So to keep light/dark
shades from washing out, **increase saturation as lightness moves away from 50%.**

**Use perceived brightness:** every hue has an inherent perceived brightness
(yellow looks lighter than blue at identical HSL lightness). Perceived brightness
peaks at yellow/cyan/magenta (60°/180°/300°) and bottoms at red/green/blue
(0°/120°/240°).

**Change brightness by rotating hue:** adjusting lightness alone drains intensity
(pushes toward white/black). Instead, **rotate the hue toward the nearest bright
hue** (60/180/300) to lighten, or toward the nearest dark hue (0/120/240) to
darken. Great for yellow palettes: rotate toward orange as you darken so shades
stay warm/rich, not dull brown. Keep rotations to **20–30° max** or it becomes a
different color.

### Greys don't have to be grey

True grey is 0% saturation, but most "greys" we like are saturated. That
saturation sets **temperature**: add a bit of blue for cool greys, a bit of
yellow/orange for warm greys. Keep temperature consistent by increasing saturation
on the lighter/darker shades too (or they wash out).

**Watch Club:** Our neutral surfaces are aubergine-tinted, not true grey — this is
the principle in action. Keep that purple/aubergine hue in neutral surfaces; the
memo "Tinted secondary, not neutral grey" is the same rule for our shadcn
`--secondary`: keep brand hue with reduced chroma, don't propose near-neutral
surfaces.

### Accessibility

- **Accessible doesn't have to mean ugly.** WCAG: normal text (<~18px) needs ≥
  4.5:1 contrast, large text ≥ 3:1. White-on-color often needs a *very* dark
  background to hit 4.5:1, which grabs too much attention. **Flip the contrast:**
  use dark colored text on a light colored background instead — color still
  supports the text but is less in-your-face.
- **Rotating the hue for contrast:** colored text on a colored background is
  hardest. Rather than pushing toward white, **rotate the hue toward a brighter
  color** (cyan/magenta/yellow) to gain contrast while staying colorful.
- **Don't rely on color alone.** Colorblind users can't read color-only signals
  (red/green metric arrows). Add a second cue (icons for up/down). For
  multi-series graphs, distinguish by **contrast** (light vs. dark) rather than
  distinct hues. Always use color to *support* something the design already says.

**Watch Club:** "Readable contrast over visual drama" is in our direction. Our
`<fill>-bg` + `<fill>` (tinted background + colored foreground) pattern *is* the
"flip the contrast" tactic. Never signal state with color alone — pair it with an
icon or label.

---

## 6. Creating depth

### Emulate a light source

Raised vs. inset is all one rule: **light comes from above.** A raised panel has a
lighter top edge (angled toward the sky) and darker bottom edge. An inset panel
has a shadow at the top (lip blocks light) and a lighter bottom edge. Mimic how
light hits the *profile* you want.

**Simulating it:**
- **Raised elements:** reveal a little of the top edge (people look slightly down
  at screens), hide the bottom. Make the top edge slightly *lighter* than the face
  (top border or inset shadow with slight vertical offset). Then add a small *dark*
  box shadow below for the blocked light. Keep the blur tiny (a few px) with sharp
  edges — like a wall outlet's shadow. Hand-pick the lighter color rather than
  overlaying semi-transparent white (white sucks out saturation).
- **Inset elements** ("well", inputs, checkboxes): only the bottom lip shows —
  give it a lighter bottom border/inset shadow (negative offset). Add a small dark
  inset shadow at the top for the blocked light.
- **Don't get carried away.** Borrowing real-world cues adds depth; chasing
  photorealism makes UIs busy and unclear.

### Use shadows to convey elevation

Shadows position elements on a virtual z-axis. Small/tight-blur = barely raised;
large/high-blur = close to the user. **Closer = more attention.**

- Small shadow → buttons (noticed, not dominant).
- Medium shadow → dropdowns (above the rest of the UI).
- Large shadow → modals (capture attention).

**Establish an elevation system:** ~5 fixed shadows is plenty. Define smallest and
largest, fill the middle roughly linearly.

**Combine shadows with interaction:** add a shadow to a dragged item so it pops
above the list (signals draggability); shrink/remove a button's shadow on press so
it feels pushed in. Don't think about the shadow — think about where the element
should sit on the z-axis and assign accordingly.

**Watch Club:** Our shadow tokens are the elevation system: `shadow.card`
(default), `shadow.overlay` (dialogs/dropdowns/popovers), `shadow.glow` (rare
brand emphasis). Use `shadow.overlay` for floating surfaces, `shadow.card` for
panels.

### Shadows can have two parts

Nice shadows are often two: a **larger, softer** shadow (big vertical offset, large
blur) simulating a direct-light cast shadow, plus a **tighter, darker** shadow
(small offset, small blur) for the ambient-occlusion area right under the object.
Two shadows give more control — keep the big one subtle while keeping edges
defined. **Account for elevation:** the tight dark shadow fades as an object rises,
so make it distinct at low elevation and nearly invisible at high elevation.

### Even flat designs have depth

"Flat" = no shadows/gradients, but the best flat designs still convey depth:

- **Depth with color:** lighter objects feel closer, darker feel farther. Make an
  element lighter than its background to feel raised, darker to feel inset.
- **Solid shadows:** short, vertically offset shadows with *no blur* add depth
  while keeping a flat aesthetic.
- **Overlap elements to create layers.** Offset a card so it crosses two
  backgrounds, or make an element taller than its parent so it overlaps both
  sides. Works for small controls (carousel arrows) too. For **overlapping
  images**, give each an "invisible border" matching the page background so they
  don't clash.

**Watch Club:** Our surface ramp encodes color-depth: `surface-raised`
(lifted/interactive) vs. `surface-inset` (recessed inputs/search/code) vs.
`surface` (default). Use them to convey raised/inset instead of hand-rolling
shadows.

---

## 7. Working with images

### Use good photos

Bad photos ruin an otherwise-great design. Either hire a pro (lighting,
composition, color take years) or use high-quality stock (Unsplash, etc.). **Never**
design with placeholders planning to swap in smartphone snaps later — it never
works.

### Text needs consistent contrast (over images)

A headline over a hero image is hard to read at *any* text color because the
*image* is the problem: photos have light and dark areas, so white text vanishes
in light areas and dark text vanishes in dark areas. Reduce the image's dynamic
range so contrast with the text is consistent:

- **Add an overlay:** semi-transparent black (tones down light areas, helps light
  text) or white (brightens dark areas, helps dark text).
- **Lower image contrast:** more targeted than an overlay; adjust brightness to
  compensate.
- **Colorize the image:** lower contrast, desaturate, then add a solid fill with
  "multiply" blend. Also pairs the photo with your brand colors.
- **Add a text shadow:** to preserve more of the image's dynamics, use a large
  blur, *no* offset (a subtle glow, not a drop shadow) to boost contrast only
  where needed. Combine with a slight contrast reduction.

### Everything has an intended size

Scaling images wrong hurts even when it's "safe":

- **Don't scale up icons.** Vectors don't pixelate, but a 16–24px icon blown up
  3–4× looks chunky and detail-poor. Instead, enclose the small icon in a shape
  with a background color so the icon stays near its intended size while filling
  the space.
- **Don't scale down screenshots.** Shrinking a full screenshot 70% crams too much
  detail into too little space (16px font → 4px). Instead: screenshot at a smaller
  layout (tablet), or take a *partial* screenshot, or draw a simplified UI (small
  text → lines) to convey the big picture without unreadable detail.
- **Don't scale down icons either.** A 128px logo crushed to a 16px favicon turns
  to mush. Redraw a simplified version at the target size so *you* control the
  compromises.

### Beware user-uploaded content

You can't fine-tune contrast/crops on user images, but you can contain the damage:

- **Control shape and size:** intrinsic aspect ratios wreck layouts. Center images
  in fixed containers and crop overflow (CSS `background-size: cover`, or
  `object-fit: cover`).
- **Prevent background bleed:** when an uploaded image's background matches your
  UI background, the image loses its shape. Don't fix it with a border (clashes
  with image colors) — use a subtle **inner box shadow** (or a semi-transparent
  inner border). Most people won't even notice it.

**Watch Club:** We display lots of posters/artwork from media servers (Jellyfin)
— treat them as user-uploaded: fixed containers, `object-fit: cover`, and a subtle
inner shadow/border to keep poster edges crisp against dark surfaces. Keep
poster-specific dimensions in the media component API (per foundation), not as
global size tokens.

---

## 8. Finishing touches

Small moves that make a plain design feel polished. Most leverage hierarchy,
color, and depth you already have.

### Supercharge the defaults

Liven up existing elements instead of adding new ones:

- Replace bullets with **icons** (checkmarks/arrows generically, or topical like a
  padlock for security features).
- "Promote" testimonial quotes into visual elements (bigger, colored quotation
  marks).
- Style links with custom color/weight, or a thick colorful underline that
  overlaps the text.
- Use custom checkboxes/radios in a brand color for selected states — just
  swapping browser defaults for a brand color often reads as "polished."

### Add color with accent borders

A cheap way to add flair without graphic-design skill: colorful accent borders —
across the top of a card, on active nav items, along the side of an alert, as a
short accent under a headline, or across the top of the whole layout. A colored
rectangle goes a long way.

**Watch Club:** We already use `<fill>-border` tokens and active-nav patterns;
accent borders are an easy, on-brand way to add purple/accent flair.

### Decorate your backgrounds

When a design feels plain despite good hierarchy/spacing/type:

- **Change the background color** of a panel or page section. For energy, a slight
  gradient — keep the two hues ≤ ~30° apart.
- **Repeating pattern** (e.g. Hero Patterns), full background or along one edge.
  Keep contrast with the background low for readability.
- **A simple shape or illustration** in specific spots — geometric shapes, a chunk
  of pattern, or something richer like a simplified world map. Keep contrast low so
  it doesn't fight the content.

### Don't overlook empty states

Empty states are a user's *first* interaction with a feature — don't ship the
beautiful populated screen and a blank void for the empty one.

**Tactics:** Add an image/illustration to grab attention and emphasize the
call-to-action that gets the user started. Hide supporting UI (tabs, filters) that
does nothing until content exists. Make empty states interesting, not plain.

**Watch Club:** "Continue Watching" and library screens are empty for new users —
design those empty states deliberately with a clear CTA. We have `size.icon-xl`
for prominent empty-state icons.

### Use fewer borders

Borders create separation but too many feel busy/cluttered. Before reaching for a
border, try:

- **Box shadow** — outlines like a border but more subtle (works best when the
  element differs in color from the background).
- **Two background colors** — slightly different adjacent backgrounds usually
  create enough distinction. If you already have that *and* a border, drop the
  border.
- **Extra spacing** — more separation literally creates separation, with no new
  UI.

**Watch Club:** Prefer `surface` vs. `surface-raised`/`surface-inset` contrast or
spacing tokens over adding `border` everywhere. We have `border-subtle` when a
divider really is needed.

### Think outside the box

We over-constrain ourselves with preconceptions about how components "should"
look. A dropdown is just a floating box — it can have sections, multiple columns,
supporting text, colorful icons. A table column doesn't have to be one datum;
combine non-sortable columns and add hierarchy, images, or color. Radio buttons
can be **selectable cards** instead of circles + labels. Constraints are powerful,
but sometimes freedom takes an interface to the next level.

---

## 9. Leveling up

Two habits to keep improving:

- **Look for decisions you wouldn't have made.** When you like a design, ask: "Did
  the designer do anything I'd never have thought to do?" — an inverted datepicker
  background, a button *inside* a text input, two font colors in one headline.
  Collecting these unintuitive moves grows your vocabulary.
- **Rebuild your favorite interfaces** from scratch *without peeking at devtools.*
  Explaining why your version differs surfaces tricks on your own — "reduce line
  height for headings," "add letter-spacing to uppercase," "combine multiple
  shadows."

---

## 10. Quick reference checklist

Use this as a pre-merge sanity pass on any new screen or component.

**Hierarchy**
- [ ] One clear primary action; secondary/tertiary visibly de-emphasized.
- [ ] Hierarchy carried by weight + color, not just font size.
- [ ] ≤ 3 text colors, ≤ 2 font weights; no weights < 400.
- [ ] Section titles sized as supporting content, not maxed-out because they're an
      `h1`.
- [ ] Data shown without naive `label: value`; labels de-emphasized when present.
- [ ] Icons softened (lower contrast) so they don't outshout adjacent text.

**Spacing & layout**
- [ ] Generous white space (started high, removed down).
- [ ] More space *around* groups than *within* them.
- [ ] Width capped deliberately (`readable`/`panel`/`page`); not filling the screen
      for its own sake.
- [ ] Fixed/`max-width` for elements with an optimal size; flex fills the rest.
- [ ] Designed/checked at mobile and desktop viewports.

**Type**
- [ ] Sizes from the type scale (px/rem, never `em` chains).
- [ ] Line length 45–75 chars.
- [ ] Line-height taller for small/narrow text, shorter for large/wide.
- [ ] Long-form text left-aligned; numbers right-aligned in tables.
- [ ] Letter-spacing added to all-caps text.

**Color**
- [ ] Pulling from the token shade sets, not the color picker / `lighten()`.
- [ ] No grey text on colored backgrounds — use `on-<fill>`/hand-tuned tokens.
- [ ] No opacity-derived fill states (`bg-danger/10`).
- [ ] Color never the *only* signal (pair with icon/label/contrast).
- [ ] Meets WCAG contrast (4.5:1 body, 3:1 large).

**Depth & images**
- [ ] Elevation from the shadow tokens; floating surfaces use `shadow.overlay`.
- [ ] Raised/inset conveyed via surface tokens or light-from-above shading.
- [ ] Images at intended size (don't scale icons up or screenshots down).
- [ ] User/media images in fixed containers with `object-fit: cover` + subtle
      inner shadow.

**Finishing**
- [ ] Empty states designed with illustration + CTA, not left blank.
- [ ] Borders minimized (prefer surface contrast / spacing / shadow).

---

## 11. How this maps to Watch Club

The book argues you should *build* the systems it describes. We already have them —
so applying *Refactoring UI* here mostly means **using the right token or
primitive** instead of hand-picking values. Cross-reference:
`docs/design-system/foundation.md`.

| Book concept | Watch Club equivalent |
| --- | --- |
| Limit your choices / systematize everything | The whole token set; "add a token only when meaning repeats" |
| 2–3 text colors, primary→tertiary ladder | `color.text`, `color.text-muted`, `color.text-subtle`, `color.text-disabled` |
| No grey/opacity text on colored backgrounds | Paired `color.on-<fill>` tokens; "no `bg-danger/10`" rule |
| Spacing system (relationship, not px) | `space.tight/related/group/cluster/section/page` |
| "More space around a group than within" | `<.field>`/`<.form>` rhythm: label→control `related`, field→field `cluster` |
| Sizing system (no `em`, no nitpicking px) | `size.icon*`, `size.control-*`, `size.row-lg`, `size.touch-target` |
| Cap line length / content width | `layout.readable`, `layout.panel`, `layout.page`; `<.page>` primitive |
| Prefer fixed/flex over grids | CLAUDE.md "prefer simple flex over grid" |
| Color shade sets, define up front | Fill token families (`<fill>`, `-hover`, `-active`, `-bg`, `-border`, `-ring`) |
| Greys don't have to be grey (tinted neutrals) | Aubergine-tinted surfaces; "tinted secondary, not neutral grey" memo |
| Elevation system (~5 shadows) | `shadow.card`, `shadow.overlay`, `shadow.glow` |
| Raised vs. inset via color | `surface`, `surface-raised`, `surface-inset` |
| Button hierarchy (primary/secondary/tertiary) | Button primitive variants + `danger` fill (quiet in lists, loud in confirm) |
| Radius consistency | `radius.control`, `radius.card`, `radius.full` |
| Accent borders / brand flair | `<fill>-border` tokens, active-nav accent patterns |
| Don't-rely-on-color-alone | "Readable contrast over visual drama" direction |

**Practical workflow when building a Watch Club screen:**

1. Start from the *feature* (an Ash action + a job to do), grayscale/hierarchy
   first.
2. Build the smallest useful version as a real LiveView and iterate on it.
3. Compose existing UI primitives (`<.page>`, `<.section>`, `<.card>`, `<.field>`,
   Button, Badge, Alert, Dialog) before raw styling.
4. Reach for *tokens by meaning* (`space.related`, `size.icon`, `shadow.overlay`),
   never raw Tailwind numbers, when a token exists.
5. Apply hierarchy: one primary action, de-emphasized rest; weight + color over
   size.
6. Design the empty state and both viewports before calling it done.
7. Run the quick reference checklist above.

When a screen needs something the tokens don't cover, that's a design-system
conversation (does this meaning repeat?), not a one-off raw value — exactly the
"limit your choices / define systems in advance" discipline the book is built
around.

---

*Source: Adam Wathan & Steve Schoger, *Refactoring UI*. This summary captures the
book's tactics for internal reference; consult the original for the visual
examples that accompany each technique.*
