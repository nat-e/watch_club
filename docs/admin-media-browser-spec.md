# Admin Media Browser — Implementation Spec

A new page for the Instance Administrator that lists every `Media` file on the
instance, with a right-pinned detail drawer. This spec covers the big picture,
the module layout, and how the pieces fit together. Detailed query, panel,
and test specs are deferred to follow-up sections.

## 1. Goals & non-goals

### Goals

- Provide a power-user, virtualized table that lists every `Media` on the
  instance, sortable, searchable, filterable by Media Type, Content Type, and
  Club.
- Provide a right-pinned detail drawer for the selected `Media` with three
  sections: **Content**, **Media** (technical: video / audio / subtitles),
  **File** (path, size, timestamps).
- Surface the Clubs each `Media` is reachable from, without leaking
  Library-level detail until the drawer is open.
- Support delete and "open content" / "open library" actions inferred from
  clickable elements; Play / Read affordance opens the existing playback flow
  (out of scope for this page itself).
- Honor the `Locale` of the current user when displaying Content titles
  (via the existing `Preferred Content Localization` machinery).

### Non-goals

- No Media editing, re-import, or metadata refresh from this page.
  Those remain on the Media Import Configuration page.
- No bulk actions in v1. Single-row delete only, via the drawer.
- No Grouped-by-Content view in v1. The brainstorm explored it; v1 ships the
  Flat view only. Grouped view stays as a documented follow-up.
- No "Interactions" tab from the brainstorm. The toolbar uses an explicit
  `+ Filter` button + applied chips + sort dropdown + columns popover, not
  per-header dropdowns.

### 1.1 Design-system constraints

The feature ships *without* extending the Watch Club design system. All
visual decisions map to the existing `<.badge>` variants (`default`,
`accent`, `secondary`, `success`, `muted`, `danger`) and existing layout
primitives. Notably, even though the foundation lists `warning` and `info`
as semantic fills, the `<.badge>` component does not yet ship those
variants, and we do **not** add them in v1.

Concrete mappings used throughout the spec:

| Meaning | Primitive |
| --- | --- |
| Resolution chip (4K / 1080p / 720p / SD) | `<.badge variant="muted">` |
| Content Type chip (Movie / TV Show / Book) | `<.badge variant="secondary">` |
| Media Type glyph (Video / Ebook / Audiobook) | icon inside a `border-border-subtle bg-surface-inset` `<.cluster>` cell |
| Library badge (in drawer) | `<.badge variant="secondary">` with library icon |
| Audio / subtitle language list | `<.cluster gap="tight">` of language flag glyphs (drawer-only; flag emoji, not a Badge) |
| Codec / Container / Range / Channels enum values | `<.badge variant="muted">` |
| Subtitle `Default` / `Forced` flag | `<.badge variant="muted">` |
| Applied filter chip on toolbar row 2 | `<.badge variant="accent">` with a remove × |
| Delete button (in drawer) | `<.button variant="danger">` |
| Play / Read button (in drawer) | `<.button variant="primary">` (or `accent` per existing Watch Club app patterns; final pick made in the LiveView pass) |

Layout primitives composed:

- Page shell: `<.page>` (full width) with `<.stack space="cluster">` between
  toolbar / table / drawer.
- Toolbar internals: `<.cluster gap="related">` rows.
- Drawer body: `<.stack space="cluster">` between sections; each section uses
  the foundation's `<.section>` only if a card surface is wanted — most
  drawer sections are bare on the drawer surface (per the design decisions
  earlier in this conversation).

Pulled from `CONTEXT.md`. Use these exact terms in code and copy:

- **Media** — the instance-wide local file. `Media.media_type ∈ {video, ebook, audiobook}`.
- **Content** — the work the Media is attached to (Movie, TV Show Episode, Book).
- **Content Type** — Movie / TV Show / Book.
- **Library** — a club-scoped collection of Library Items (Content).
- **Club** — the group that owns the Library. A Media is "in N clubs" when its
  attached Content has at least one Library Item in those clubs' libraries.

## 3. Big-picture architecture

```
                                ┌───────────────────────────────────────┐
                                │  /admin/media   (new LiveView)       │
                                │  WatchClubWeb.Admin.MediaBrowserPage  │
                                │                                       │
   Browser ─── HTTP/WS ───►     │  - mount: assign filters, sort,       │
                                │    columns, drawer state              │
                                │  - stream: media_rows                 │
                                │  - handle_event: filter / sort /      │
                                │    column toggle / open drawer /      │
                                │    delete / load_more                 │
                                │                                       │
                                │  composes:                            │
                                │    MediaBrowserPage.Toolbar           │
                                │    MediaBrowserPage.Table             │
                                │    MediaBrowserPage.DetailDrawer      │
                                └─────────────────┬─────────────────────┘
                                                  │
                                                  ▼
                                ┌───────────────────────────────────────┐
                                │  WatchClub.Media (Ash domain)         │
                                │                                       │
                                │  code interfaces (called by LiveView):│
                                │    browse_media!(query:, load:, …)   │
                                │    get_media!(id, load:, …)          │
                                │    destroy_media!(media, …)          │
                                └─────────────────┬─────────────────────┘
                                                  │
                                                  ▼
                                ┌───────────────────────────────────────┐
                                │  WatchClub.Media.Media (resource)     │
                                │                                       │
                                │  one new read action:                 │
                                │    :browse                            │
                                │      arguments: search, media_type,   │
                                │        club_id, sort_by, sort_dir     │
                                │      keyset paginated                 │
                                │      prepare builds the query and the │
                                │        preload tree from arguments    │
                                │                                       │
                                │  existing :read reused for drawer     │
                                │    (called with get_by + heavy load:) │
                                │  existing :destroy reused for delete  │
                                └─────────────────┬─────────────────────┘
                                                  │
                                                  ▼
                                         Existing resources:
                                         Media, Video, Ebook, Audiobook,
                                         Tracks, Content, Library,
                                         LibraryItem, Club
```

Three layers:

1. **Domain layer** — one new read action (`:browse`) on `WatchClub.Media.Media`,
   plus new aggregates and calculations. Three new code interfaces on the
   `WatchClub.Media` domain so the LiveView never calls `Ash.read/2` directly.
   No new resources, attributes, or migrations.
2. **LiveView layer** — one new page, three child function components.
3. **UI layer** — composes existing primitives (`<.page>`, `<.section>`,
   `<.stack>`, `<.cluster>`, `<.card>`, `<.table>`, `<.badge>`,
   `<.avatar_group>`, `<.tmdb_poster>`, `<.infinite_scroll_trigger>`). One new
   function component family for the right-pinned drawer (see §5).

## 4. Module overview

### 4.1 New modules

#### Domain (lib/watch_club/media/)

No new resources. The work is one new read action plus aggregates and
calculations on the existing `Media` resource, exposed through code interfaces
on the `WatchClub.Media` domain.

**One new read action on `WatchClub.Media.Media`:**

| Action | Purpose |
| --- | --- |
| `:browse` | Keyset-paginated read used by both the table (many rows) and the drawer (one row, via `get_by: [:id]` and a heavier `load:`). Arguments: `search`, `media_type`, `club_id`, `sort_by` (`:imported_at \| :path`), `sort_dir` (`:asc \| :desc`). A `prepare` block builds the query from these arguments. |

Filter/sort logic lives in the action's `prepare` block — not in a sidecar
helper module. The earlier draft proposed a `WatchClub.Media.AdminBrowserQuery`
helper; that has been dropped as an anti-pattern (Ash convention is to put
query shaping in the action itself, not in caller-side helpers).

**Preload strategy for the table (v1):**

The "clubs for this Media" data drives the Clubs avatar column. The path
Media → club is a *union* of three attachment routes (Video → Movie /
Video → TvShowEpisode → TvShow, Ebook → Book, Audiobook → Book), so a
single Ash aggregate doesn't compose cleanly. The rest of the codebase
already computes club lists in Elixir from a preloaded `library_items`
tree (see `WatchClub.Contents.ContentView.in_clubs/2`).

For v1 we follow that pattern: `:browse` preloads the relevant attachment
+ content + library_items + library + club tree, and a presenter helper
computes the per-row club list. This trades a denser preload for code
consistency with the existing project. A future optimization pass can
replace it with aggregates/calculations.

Sort options for v1: `imported_at` (default desc) and `path`. Sorting by
content title is queued — Content titles live in localizations, not a
single column, so server-side sort needs a localization-resolution step
that isn't worth solving in v1.

**New code interfaces on `WatchClub.Media` (domain):**

```elixir
defmodule WatchClub.Media do
  use Ash.Domain

  resources do
    resource WatchClub.Media.Media do
      define :browse_media, action: :browse
      define :get_media, action: :read, get_by: [:id]
      define :destroy_media, action: :destroy
    end
    # … other resources unchanged
  end
end
```

The LiveView calls `WatchClub.Media.browse_media!/1`, `get_media!/2`, and
`destroy_media!/1`. It never calls `Ash.read/2` directly.

**Policy update on `Media`:**

The existing policy block names the actions it covers explicitly:

```elixir
policy action([:read, :under_path_prefix]) do
  authorize_if actor_attribute_equals(:administrator?, true)
  authorize_if actor_attribute_equals(:system?, true)
end
```

The new `:browse` action must be added to this list (or the policy
generalized to `policy action_type(:read)`). Spec §7 makes this explicit.

#### Web (lib/watch_club_web/live/admin/)

This will be the first page under a new `Admin` namespace. Layout mirrors
`lib/watch_club_web/live/clubs/library_page/` (one LiveView module + a
sub-folder of presentational components and small state helpers).

```
lib/watch_club_web/live/admin/
├── media_browser_page.ex            # LiveView (mount, handle_params, handle_event, render)
└── media_browser_page/
    ├── toolbar.ex                   # function component: search + filter + sort + columns
    ├── table.ex                     # function component: table head + stream rows + load-more sentinel
    ├── media_row.ex                 # function component: one row
    ├── detail_drawer.ex             # function component + its private section sub-components
    └── state.ex                     # one struct + submodules (Filter, Sort, Columns, Stream)
```

Two consolidations versus the precedent in
`lib/watch_club_web/live/clubs/library_page/`:

- `detail_drawer.ex` carries its content / video / audio / subtitle / file
  section components as private functions in the same file. We can split
  them out later if the file outgrows ~400 lines, but they're all rendering
  the same input and share enough to live together.
- `state.ex` exposes one `State` struct with nested submodules for Filter,
  Sort, Columns, and Stream — see §5.6 for the shape. Mirrors the
  `ContentStreamState` precedent but bundles the four concerns the
  LiveView juggles into one file.

### 4.2 Existing modules reused

| Module | Role |
| --- | --- |
| `WatchClub.Media.Media` | New actions added here. Existing `:destroy` reused for delete. |
| `WatchClub.Contents.ContentView` | Reused to resolve Preferred Content Localization for titles and to compute the "in clubs" list. |
| `WatchClub.Accounts.User` | `administrator?` boolean drives authorization. |
| `WatchClubWeb.Components.UI.{Layout, Table, Badge, Button, Avatar}` | Page composition. |
| `WatchClubWeb.Components.UI.InfiniteScroll` | `<.infinite_scroll_trigger>` for keyset paging. |
| `WatchClubWeb.Components.Contents.TmdbPoster` | Drawer hero poster (with built-in nil-path fallback). |

### 4.3 Modules touched

| Module | Change |
| --- | --- |
| `lib/watch_club/media/media.ex` | Add `:browse` read action with arguments + `prepare` (preloads attachment + content + library_items + library + club); extend the read policy to cover `:browse`. |
| `lib/watch_club/media.ex` | Add code interfaces `browse_media`, `get_media`, `destroy_media`. |
| `lib/watch_club_web/router.ex` | Add `/admin` live scope with `on_mount: :ensure_administrator`; mount `/admin/media`. |
| `lib/watch_club_web/user_auth.ex` | Add `:ensure_administrator` `on_mount` hook (or equivalent), if not present. |
| `lib/watch_club_web/storybook/_root.index.exs` | Register the production storybook entry. |
| `lib/watch_club_web/storybook/brainstorm/admin-media-browser.story.exs` | Delete once production story is in place. |

## 5. Module responsibilities

### 5.1 `MediaBrowserPage` (LiveView)

- Mounts with default filters (none), default sort (`imported_at desc`), default
  visible columns, and an empty drawer state.
- Owns `:streams.media_rows` (Phoenix LiveView stream).
- Holds four assigns structs: `:filter_state`, `:sort_state`, `:columns_state`,
  `:stream_state`. Each has its own helper module so the LiveView itself stays
  thin.
- `handle_params` reads URL query params for filters / sort so the page is
  bookmarkable. Drawer selection is *not* in the URL (it's transient).
- `handle_event` covers: open/close drawer, toggle filter chip, set sort,
  toggle column, search input change (debounced), load_more, delete_media.

### 5.2 `Toolbar`

- Pure function component, no state of its own.
- Receives `:filter_state`, `:sort_state`, `:columns_state`, `:result_count`.
- Two visual rows: controls (search, `+ Filter`, sort, columns) and applied
  chips (only when filters are active).
- Filter popover, sort dropdown, columns popover are rendered as siblings that
  the LiveView toggles open via `:open_popover` assign (one popover at a time).

### 5.3 `Table`

- Pure function component.
- Renders the table head and the streamed rows.
- Tail-renders `<.infinite_scroll_trigger>` when more pages exist (per
  `State.Stream.can_load_more?/1`).
- Delegates one row to `MediaRow`.

### 5.4 `MediaRow`

- Pure function component.
- One row, composed of: media-type glyph + filename, content-type badge,
  matched-content inline, clubs avatar group, audio/subtitle flag strips,
  resolution badge, imported relative time.
- Emits `phx-click="open_drawer"` with the row id.

### 5.5 `DetailDrawer`

- Pure function component. Hero + content / video / audio / subtitle / file
  sections live as private function components in the same file.
- Receives a single, fully-preloaded `Media`. The LiveView fetches via
  `WatchClub.Media.get_media!(id, load: [...heavy tree...])` when a row is
  opened — same code interface that backs the table's drawer, with the
  drawer-specific `load:` tree (tracks, full library list with names, last
  Media Import). This keeps the table action and the drawer fetch on the
  same source-of-truth read; after a `destroy_media` the LiveView re-streams
  from `browse_media` and clears the drawer.
- Composes: hero (filename + Play/Delete actions), content section, video
  section (only when `media_type == :video`), audio section (only when
  audio tracks exist), subtitle section (only when subtitle tracks exist),
  file section.
- Split into separate files if the module exceeds ~400 lines.

### 5.6 `State` (one struct, nested submodules)

A single file (`state.ex`) holding the page's transient state. One outer
struct + four submodules under it, each with pure helpers:

```elixir
defmodule MediaBrowserPage.State do
  defstruct [:filter, :sort, :columns, :stream]

  defmodule Filter do
    defstruct media_type: nil, club_id: nil, search: ""
    def new/0
    def toggle(filter, key, value)
    def set(filter, key, value)
    def clear/1
    def to_query_params/1
    def from_params/1
  end

  defmodule Sort do
    defstruct field: :imported_at, direction: :desc
    def new/0
    def set(sort, field, direction)
    def to_query_params/1
    def from_params/1
  end

  defmodule Columns do
    defstruct visible: MapSet.new([...defaults...])
    def new/0
    def toggle(columns, key)
    def visible?(columns, key)
  end

  defmodule Stream do
    defstruct page: nil, next_keyset: nil, can_load_more?: false
    def initial/0
    def append(stream, page)
    def reset(stream)
    def can_load_more?(stream)
  end

  def new/0
  def from_params(params)
  def to_query_params(state)
end
```

Mirrors the `ContentStreamState` precedent for the inner `Stream` submodule;
the other three submodules are new but follow the same pure-functions-only
convention. Testable in isolation.

## 6. Data flow

```
URL ─────► handle_params ─────► State.from_params/1
                                  │
                                  ▼
                           WatchClub.Media.browse_media!(
                             actor: scope.user,
                             query: [
                               arguments: %{search: …, media_type: …,
                                            club_id: …,
                                            sort_by: …, sort_dir: …}
                             ],
                             load: [
                               video: [movie: [content: [library_items: [library: :club]]],
                                       tv_show_episode: [tv_show: [content: [library_items: [library: :club]]]]],
                               ebook: [book: [content: [library_items: [library: :club]]]],
                               audiobook: [book: [content: [library_items: [library: :club]]]]
                             ],
                             page: [after: keyset, limit: 50]
                           )
                                  │
                                  ▼
                           State.Stream.append(page)
                                  │
                                  ▼
                           stream_insert :media_rows
                                  │
                                  ▼
                           Table renders <- MediaRow per row

User clicks row ─────► handle_event "open_drawer" ─────► WatchClub.Media.get_media!(
                                                           id,
                                                           actor: scope.user,
                                                           load: [...drawer tree...]
                                                         )
                                                          │
                                                          ▼
                                                   assign :drawer_media
                                                          │
                                                          ▼
                                                   DetailDrawer renders

User clicks Delete ──► handle_event "delete_media" ────► WatchClub.Media.destroy_media!(
                                                           drawer_media,
                                                           actor: scope.user
                                                         )
                                                          │
                                                          ▼
                                                   stream_delete :media_rows
                                                   clear :drawer_media
```

All resource access goes through code interfaces on `WatchClub.Media`. The
LiveView never calls `Ash.read/2` / `Ash.get!/2` directly.

Filters, sort, search, and column visibility are entirely client-state at the
LiveView level — no per-user persistence in v1 (session-only, matches the
brainstorm decision). The URL carries filter + sort so users can bookmark and
share a filtered view.

## 7. Authorization

Two layers, both enforced:

1. **`live_session` on_mount hook.** A new `WatchClubWeb.UserAuth`
   `:ensure_administrator` `on_mount` hook checks `current_user.administrator?`
   on socket connect. If false, halts with a 404-style redirect — the page's
   existence is not leaked. This single hook covers both direct URL access
   and live navigation; no separate router plug is needed.
2. **Ash policy.** The existing `Media` policy explicitly names the actions
   it covers: `policy action([:read, :under_path_prefix])`. The new
   `:browse` action **must be added** to this list (or the policy
   generalized to `policy action_type(:read)`); a new action is not
   automatically authorized just because it is a read.

The on_mount hook protects against accidental URL exposure; Ash protects
against the hook being mis-configured. Both are required.

## 8. Routes

```elixir
scope "/admin", WatchClubWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :require_administrator,
    on_mount: [
      {WatchClubWeb.UserAuth, :ensure_authenticated},
      {WatchClubWeb.UserAuth, :ensure_administrator}
    ] do
    live "/media", Admin.MediaBrowserPage, :index
  end
end
```

Single route in v1. Future admin pages (Media Imports, Automation Services,
Clubs admin) join the same scope and reuse the same `live_session`.

## 9. Storybook

Two stories will exist by end of feature:

| Path | Purpose |
| --- | --- |
| `lib/watch_club_web/storybook/admin-media-browser.story.exs` | Production-grade story of the static page (no LiveView), with desktop and mobile tabs covering representative states: empty, populated, filtered, drawer-open, audiobook (no video section), ebook (no video / audio / subtitle sections). |
| `lib/watch_club_web/storybook/brainstorm/admin-media-browser.story.exs` | Removed once the production story lands and the design decisions are settled. |

The production story is registered in `_root.index.exs`. Brainstorm folder
remains as the home of future exploratory work.

### 9.1 Mobile

The mobile experience is intentionally narrower than desktop. The same
LiveView serves both; layout collapses via Tailwind breakpoints.

What survives on mobile:

- The list, rendered as **cards** (not table rows). Three lines per card:
  - Line 1: media-type glyph + filename
  - Line 2: content-type chip + matched-content title (truncated)
  - Line 3: club avatar group + resolution badge + relative time
- The detail drawer, rendered as a **full-screen sheet** that takes over when
  a card is tapped. Sections are stacked the same way as desktop.
- Search and the `+ Filter` button (bottom-sheet popover on tap).
- Applied filter chips as a horizontally-scrolling row beneath the toolbar.

What gets cut from mobile v1:

- Sort dropdown (default `imported_at desc` only).
- Column picker.
- Audio / subtitle flag strips on the row (drawer-only).
- Eyebrow ("Admin · Media") and the description copy.

The mobile design is a separate concern in the LiveView render — likely
two `render/1` branches gated on a `:layout` assign computed from a
client-side viewport hook, or pure Tailwind `md:` / `lg:` classes. Decision
deferred until the desktop view is built.

## 10. Telemetry / Observability

Out of scope for v1. The LiveView inherits the existing
`WatchClubWeb.Telemetry` instrumentation; no custom events needed unless we
discover a hot path.

## 11. Open questions

### Resolved

These were open during earlier passes; settled now so the next spec layer
can build on them.

1. **Delete confirmation.** *Inline two-step in the drawer.* Clicking
   "Delete" in the drawer hero swaps the button row for "Confirm delete?"
   (`<.button variant="danger">`) + "Cancel" (`<.button variant="ghost">`).
   No modal in v1. Rationale: the drawer is already a focused single-row
   surface; a modal-on-top-of-drawer adds chrome without adding clarity.

### Still open

These need answers before the next layer of spec is written:

1. **Search scope.** Search-by-filename and search-by-content-title both make
   sense, but they're different indexes. Single combined search box or two?
2. **Sort fields.** Confirm v1 sort options: `imported_at`, `filename`,
   `content_title`, `size`, `resolution`. Defaults to `imported_at desc`.
3. **Optional columns.** Confirm the default-on / default-off split: I propose
   default-on for Clubs, Audio, Subtitles, Resolution, Imported; default-off
   for Codec, Container, Path. Required (not togglable): File, Matched
   Content.

## 12. Out of scope, queued

- Grouped-by-Content view
- Bulk delete
- Per-user column preferences (persisted)
- Re-import / refresh metadata from this page
- Move / rename file from this page
- Header-driven sort + per-column filter UX (Airtable / Notion pattern)
