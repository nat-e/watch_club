defmodule WatchClubWeb.Storybook.Brainstorm.AdminMediaBrowser do
  @moduledoc """
  Temporary brainstorm mockup for the Instance Administrator's Media browser.

  Two views explored:

    * Flat — every Media file, one row per file. Power-user list with File
      as the primary identity column and a right-pinned drawer.
    * Grouped — Media grouped by Content. The Content band carries
      Content-domain facts (libraries, type, identity); the Media table
      beneath carries per-Media facts. Always visible, no expand/collapse.

  Composes the Watch Club layout primitives and follows foundation rules:
  tokens name meaning, color is reserved for state, technical attributes
  stay neutral.

  Safe to delete after the design decision is accepted or rejected.
  """
  use PhoenixStorybook.Story, :page
  use Phoenix.Component

  import WatchClubWeb.Components.UI.Avatar
  import WatchClubWeb.Components.UI.Badge
  import WatchClubWeb.Components.UI.Button
  import WatchClubWeb.Components.UI.Layout
  import WatchClubWeb.Components.UI.Table
  import WatchClubWeb.Components.Contents.TmdbPoster

  def doc do
    "Two views for the Media admin page: a flat power-user list with a right-pinned drawer, and a grouped-by-Content view where Content rows carry Content-domain facts and Media rows beneath carry per-file facts."
  end

  def navigation do
    [
      {:flat, "Flat", {:fa, "list"}},
      {:grouped, "Grouped by Content", {:fa, "folder-tree"}},
      {:header_driven, "Flat · header-driven", {:fa, "table-columns"}},
      {:interactions, "Interactions", {:fa, "sliders"}},
      {:mobile, "Mobile", {:fa, "mobile-screen"}}
    ]
  end

  # ---------------------------------------------------------------------------
  # Header-driven tab — sort + columns live inside each header
  # ---------------------------------------------------------------------------

  def render(%{tab: :header_driven} = assigns) do
    assigns =
      assigns
      |> assign(rows: media_rows())
      |> assign(selected: hd(media_rows()))
      |> assign(open_column: "Resolution")

    ~H"""
    <.theme_frame>
      <.page space="cluster" width="full">
        <.eyebrow_header
          eyebrow="Admin · Media"
          title="Header-driven sort & columns"
          description="Click a column header to sort, filter, or hide that column. Add columns via the '+' at the end of the row. Toolbar keeps only search and applied filters."
        />

        <.view_toggle current={:flat} />
        <.minimal_toolbar />

        <div class="grid gap-cluster lg:grid-cols-[minmax(0,1fr)_28rem]">
          <.card surface="default" padding="none" class="relative overflow-visible">
            <.table class="min-w-full">
              <.header_driven_table_head open_column={@open_column} />
              <.table_body>
                <.flat_media_row :for={row <- @rows} row={row} selected={row.id == @selected.id} />
              </.table_body>
            </.table>
          </.card>

          <.detail_drawer media={@selected} />
        </div>
      </.page>
    </.theme_frame>
    """
  end

  attr :open_column, :string, default: nil

  defp header_driven_table_head(assigns) do
    ~H"""
    <.table_header>
      <.table_row class="relative">
        <.sortable_head label="File" sort={:asc} active={false} />
        <.sortable_head label="Type" sort={:none} active={false} width="6rem" />
        <.sortable_head label="Matched Content" sort={:none} active={false} />
        <.sortable_head label="Clubs" sort={:none} active={false} width="7rem" />
        <.sortable_head label="Audio" sort={:none} active={false} width="6rem" />
        <.sortable_head label="Subtitles" sort={:none} active={false} width="6rem" />
        <.sortable_head
          label="Resolution"
          sort={:desc}
          active={true}
          width="5rem"
          open={@open_column == "Resolution"}
        />
        <.sortable_head label="Imported" sort={:desc} active={false} width="5rem" />
        <.add_column_head />
      </.table_row>
    </.table_header>
    """
  end

  attr :label, :string, required: true
  attr :sort, :atom, required: true
  attr :active, :boolean, default: false
  attr :open, :boolean, default: false
  attr :width, :string, default: nil

  defp sortable_head(assigns) do
    ~H"""
    <th
      data-slot="table-head"
      class={[
        "relative h-10 px-related text-left align-middle text-xs font-medium whitespace-nowrap",
        @active && "text-text",
        !@active && "text-text-muted"
      ]}
      style={@width && "width: #{@width}"}
    >
      <button
        type="button"
        class="inline-flex items-center gap-tight rounded-control px-1 py-0.5 hover:bg-surface-hover"
      >
        <span>{@label}</span>
        <span :if={@sort == :asc} class="text-text-subtle">
          <Lucideicons.arrow_up class="size-icon-sm" />
        </span>
        <span :if={@sort == :desc} class="text-text-subtle">
          <Lucideicons.arrow_down class="size-icon-sm" />
        </span>
        <Lucideicons.chevron_down
          :if={@sort == :none}
          class="size-icon-sm text-text-subtle opacity-0 group-hover:opacity-100"
        />
      </button>

      <.header_popover :if={@open} label={@label} />
    </th>
    """
  end

  attr :label, :string, required: true

  defp header_popover(assigns) do
    ~H"""
    <div class="absolute left-0 top-full z-10 mt-1 w-[16rem]">
      <.popover>
        <.header_action_row icon={:arrow_up}>
          Sort {@label} ascending
        </.header_action_row>
        <.header_action_row icon={:arrow_down} active>
          Sort {@label} descending
        </.header_action_row>
        <div class="border-t border-border-subtle my-tight"></div>
        <.header_action_row icon={:search}>
          Filter by {@label}…
        </.header_action_row>
        <.header_action_row icon={:eye_off}>
          Hide column
        </.header_action_row>
        <.header_action_row icon={:arrow_left_right}>
          Move column
        </.header_action_row>
      </.popover>
    </div>
    """
  end

  attr :icon, :atom, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp header_action_row(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "flex w-full items-center gap-related rounded-control px-related py-1.5 text-sm hover:bg-surface-hover",
        @active && "bg-surface-hover text-text",
        !@active && "text-text-muted"
      ]}
    >
      <.dynamic_icon name={@icon} class="size-icon-sm text-text-subtle" />
      <span class="truncate text-left">{render_slot(@inner_block)}</span>
    </button>
    """
  end

  defp add_column_head(assigns) do
    ~H"""
    <th
      data-slot="table-head"
      class="h-10 w-10 px-2 text-left align-middle"
    >
      <button
        type="button"
        class="grid size-6 place-items-center rounded-control text-text-subtle hover:bg-surface-hover hover:text-text"
        aria-label="Add column"
        title="Add column"
      >
        <Lucideicons.plus class="size-icon-sm" />
      </button>
    </th>
    """
  end

  defp minimal_toolbar(assigns) do
    ~H"""
    <.card surface="default" padding="cluster">
      <.stack space="related">
        <.cluster space="related">
          <div class="relative grow min-w-[18rem]">
            <Lucideicons.search class="absolute left-3 top-1/2 size-icon-sm -translate-y-1/2 text-text-subtle" />
            <input
              type="text"
              placeholder="Search file name or content…"
              class="h-control-md w-full rounded-control border border-border bg-surface-inset pl-9 pr-3 text-sm text-text placeholder:text-text-subtle focus:border-border-focus focus:outline-none focus:ring-2 focus:ring-focus-ring"
            />
          </div>
          <div class="ml-auto text-xs text-text-subtle">
            Click any column header for sort, filter, hide. Click <strong class="text-text">+</strong> to add columns.
          </div>
        </.cluster>

        <.cluster space="tight">
          <.filter_chip label="Media" value="Video" />
          <.filter_chip label="Library" value="Movie Night · Sci-Fi" />
        </.cluster>

        <div class="flex items-center justify-between text-xs text-text-subtle">
          <span>1,847 Media · showing 12 · Sorted by Resolution (4K → SD)</span>
          <span class="inline-flex items-center gap-tight">
            <Lucideicons.infinity class="size-icon-sm" /> Virtualized
          </span>
        </div>
      </.stack>
    </.card>
    """
  end

  # ---------------------------------------------------------------------------
  # Interactions tab — shows the toolbar controls in their open state
  # ---------------------------------------------------------------------------

  def render(%{tab: :interactions} = assigns) do
    ~H"""
    <.theme_frame>
      <.page space="cluster" width="full">
        <.eyebrow_header
          eyebrow="Reference"
          title="Toolbar interactions"
          description="What each toolbar control reveals when opened. Static reference for the live implementation."
        />

        <.stack space="cluster">
          <.interaction_section title="1. Filter popover">
            <:description>
              Clicking <strong>+ Filter</strong> opens a categorized popover.
              Each row toggles a value on/off. Applied filters become removable chips
              on the toolbar's second row.
            </:description>

            <div class="grid gap-cluster lg:grid-cols-2">
              <.interaction_card label="Before">
                <.cluster space="related">
                  <.button id="ix-add-filter-1" variant="secondary" size="md">
                    <:icon><Lucideicons.plus /></:icon>
                    Filter
                  </.button>
                  <span class="text-xs text-text-subtle">No filters applied</span>
                </.cluster>
              </.interaction_card>

              <.interaction_card label="Open">
                <.cluster space="related" class="items-start">
                  <.button id="ix-add-filter-2" variant="secondary" size="md">
                    <:icon><Lucideicons.plus /></:icon>
                    Filter
                  </.button>
                  <.popover>
                    <.popover_search placeholder="Filter by…" />
                    <.popover_section title="Media">
                      <.popover_check checked>Video</.popover_check>
                      <.popover_check>Ebook</.popover_check>
                      <.popover_check>Audiobook</.popover_check>
                    </.popover_section>
                    <.popover_section title="Content">
                      <.popover_check checked>Movie</.popover_check>
                      <.popover_check checked>TV Show</.popover_check>
                      <.popover_check>Book</.popover_check>
                    </.popover_section>
                    <.popover_section title="Match status">
                      <.popover_check>Matched</.popover_check>
                      <.popover_check checked>No match</.popover_check>
                      <.popover_check>Failed</.popover_check>
                    </.popover_section>
                    <.popover_section title="Library">
                      <.popover_check checked>Movie Night · Sci-Fi</.popover_check>
                      <.popover_check>Anders · Watchlist</.popover_check>
                      <.popover_check>Family Room · Saturday</.popover_check>
                      <.popover_check>Quiet Hours · Sci-Fi</.popover_check>
                    </.popover_section>
                  </.popover>
                </.cluster>
              </.interaction_card>
            </div>

            <.interaction_card label="Applied (toolbar row 2)">
              <.cluster space="tight">
                <.filter_chip label="Media" value="Video" />
                <.filter_chip label="Content" value="Movie, TV Show" />
                <.filter_chip label="Match" value="No match" />
                <.filter_chip label="Library" value="Movie Night · Sci-Fi" />
                <button
                  type="button"
                  class="inline-flex h-7 items-center px-2 text-xs text-text-subtle hover:text-text"
                >
                  Clear all
                </button>
              </.cluster>
            </.interaction_card>
          </.interaction_section>

          <.interaction_section title="2. Sort menu">
            <:description>
              Clicking the sort dropdown reveals a list of sortable fields. Direction toggles per field.
            </:description>

            <div class="grid gap-cluster lg:grid-cols-2">
              <.interaction_card label="Before">
                <.dropdown_button label="Sort: Last import" icon={:arrow_down_wide_narrow} />
              </.interaction_card>
              <.interaction_card label="Open">
                <.stack space="tight" class="items-start">
                  <.dropdown_button label="Sort: Last import" icon={:arrow_down_wide_narrow} />
                  <.popover width="14rem">
                    <.popover_radio checked>
                      Last import
                      <:hint>Newest first</:hint>
                    </.popover_radio>
                    <.popover_radio>
                      File name
                      <:hint>A → Z</:hint>
                    </.popover_radio>
                    <.popover_radio>
                      Matched Content
                      <:hint>A → Z</:hint>
                    </.popover_radio>
                    <.popover_radio>
                      Size
                      <:hint>Largest first</:hint>
                    </.popover_radio>
                    <.popover_radio>
                      Resolution
                      <:hint>4K → SD</:hint>
                    </.popover_radio>
                    <div class="border-t border-border-subtle pt-tight mt-tight px-related">
                      <button
                        type="button"
                        class="inline-flex items-center gap-tight text-xs text-text-muted hover:text-text"
                      >
                        <Lucideicons.arrow_up_narrow_wide class="size-icon-sm" />
                        Reverse order
                      </button>
                    </div>
                  </.popover>
                </.stack>
              </.interaction_card>
            </div>
          </.interaction_section>

          <.interaction_section title="3. Columns picker">
            <:description>
              Toggle which optional columns appear. Required columns (File, Matched Content) are not in the list.
              Choices are session-only.
            </:description>

            <div class="grid gap-cluster lg:grid-cols-2">
              <.interaction_card label="Before">
                <.dropdown_button label="Columns" icon={:columns_3} />
              </.interaction_card>
              <.interaction_card label="Open">
                <.stack space="tight" class="items-start">
                  <.dropdown_button label="Columns" icon={:columns_3} />
                  <.popover width="14rem">
                    <.popover_check checked>Clubs</.popover_check>
                    <.popover_check checked>Audio</.popover_check>
                    <.popover_check checked>Subtitles</.popover_check>
                    <.popover_check checked>Resolution</.popover_check>
                    <.popover_check checked>Size</.popover_check>
                    <.popover_check checked>Imported</.popover_check>
                    <.popover_check>Codec</.popover_check>
                    <.popover_check>Container</.popover_check>
                    <.popover_check>Path</.popover_check>
                    <div class="border-t border-border-subtle pt-tight mt-tight px-related text-xs text-text-subtle">
                      Session-only
                    </div>
                  </.popover>
                </.stack>
              </.interaction_card>
            </div>
          </.interaction_section>
        </.stack>
      </.page>
    </.theme_frame>
    """
  end

  # ---------------------------------------------------------------------------
  # Interactions — primitives
  # ---------------------------------------------------------------------------

  attr :title, :string, required: true
  slot :description, required: true
  slot :inner_block, required: true

  defp interaction_section(assigns) do
    ~H"""
    <.card surface="default" padding="cluster" class="grid gap-cluster">
      <.stack space="related">
        <h2 class="text-lg font-heading font-semibold tracking-tight text-text">
          {@title}
        </h2>
        <p class="max-w-readable text-sm leading-6 text-text-muted">
          {render_slot(@description)}
        </p>
      </.stack>
      <.stack space="cluster">
        {render_slot(@inner_block)}
      </.stack>
    </.card>
    """
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp interaction_card(assigns) do
    ~H"""
    <div class="grid gap-related rounded-control border border-border-subtle bg-surface-inset p-cluster">
      <span class="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-text-subtle">
        {@label}
      </span>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :width, :string, default: "18rem"
  slot :inner_block, required: true

  defp popover(assigns) do
    ~H"""
    <div
      class="grid gap-tight rounded-card border border-border bg-surface-overlay p-related shadow-overlay"
      style={"width: #{@width}"}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :placeholder, :string, required: true

  defp popover_search(assigns) do
    ~H"""
    <div class="relative">
      <Lucideicons.search class="absolute left-2.5 top-1/2 size-icon-sm -translate-y-1/2 text-text-subtle" />
      <input
        type="text"
        placeholder={@placeholder}
        class="h-8 w-full rounded-control border border-border-subtle bg-surface-inset pl-8 pr-2 text-xs text-text placeholder:text-text-subtle"
      />
    </div>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp popover_section(assigns) do
    ~H"""
    <div class="grid gap-tight">
      <span class="px-related text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-text-subtle">
        {@title}
      </span>
      <div class="grid">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :checked, :boolean, default: false
  slot :inner_block, required: true

  defp popover_check(assigns) do
    ~H"""
    <button
      type="button"
      class="flex items-center gap-related rounded-control px-related py-1.5 text-sm text-text hover:bg-surface-hover"
    >
      <span class={[
        "grid size-4 shrink-0 place-items-center rounded-[3px] border",
        @checked && "border-accent bg-accent text-on-accent",
        !@checked && "border-border bg-surface"
      ]}>
        <Lucideicons.check :if={@checked} class="size-3" />
      </span>
      <span class="truncate">{render_slot(@inner_block)}</span>
    </button>
    """
  end

  attr :checked, :boolean, default: false
  slot :hint
  slot :inner_block, required: true

  defp popover_radio(assigns) do
    ~H"""
    <button
      type="button"
      class="flex items-center gap-related rounded-control px-related py-1.5 text-sm text-text hover:bg-surface-hover"
    >
      <span class={[
        "grid size-4 shrink-0 place-items-center rounded-full border",
        @checked && "border-accent",
        !@checked && "border-border"
      ]}>
        <span :if={@checked} class="size-2 rounded-full bg-accent" />
      </span>
      <span class="grow truncate text-left">{render_slot(@inner_block)}</span>
      <span :if={@hint != []} class="text-xs text-text-subtle">{render_slot(@hint)}</span>
    </button>
    """
  end

  # ---------------------------------------------------------------------------
  # Grouped tab
  # ---------------------------------------------------------------------------

  def render(%{tab: :grouped} = assigns) do
    assigns =
      assigns
      |> assign(groups: content_groups())
      |> assign(unmatched: unmatched_block())
      |> assign(selected: hd(content_groups()).media |> hd())

    ~H"""
    <.theme_frame>
      <.page space="cluster" width="full">
        <.eyebrow_header
          eyebrow="Admin · Media"
          title="Media browser"
          description="Every Media file on the instance, grouped by the Content they belong to."
        />

        <.view_toggle current={:grouped} />
        <.toolbar />

        <div class="grid gap-cluster lg:grid-cols-[minmax(0,1fr)_28rem]">
          <.stack space="cluster">
            <.content_block :for={group <- @groups} group={group} selected_id={@selected.id} />
            <.unmatched_block block={@unmatched} />
          </.stack>

          <.detail_drawer media={@selected} />
        </div>
      </.page>
    </.theme_frame>
    """
  end

  # ---------------------------------------------------------------------------
  # Mobile tab — narrow viewport, cards instead of table rows
  # ---------------------------------------------------------------------------

  def render(%{tab: :mobile} = assigns) do
    assigns =
      assigns
      |> assign(rows: media_rows())
      |> assign(selected: hd(media_rows()))

    ~H"""
    <.theme_frame>
      <div class="grid gap-cluster p-cluster">
        <header class="text-center">
          <p class="text-xs text-text-subtle">
            Mobile mockup at 390px. Resize the storybook iframe or use device emulation.
          </p>
        </header>

        <div class="mx-auto grid grid-cols-1 gap-cluster md:grid-cols-2 md:place-items-start">
          <.phone_frame label="List">
            <.mobile_list rows={@rows} selected_id={@selected.id} />
          </.phone_frame>

          <.phone_frame label="Detail sheet">
            <.mobile_detail_sheet media={@selected} />
          </.phone_frame>
        </div>
      </div>
    </.theme_frame>
    """
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp phone_frame(assigns) do
    ~H"""
    <div class="grid gap-related">
      <span class="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-text-subtle text-center">
        {@label}
      </span>
      <div
        class="overflow-hidden rounded-[2rem] border-[8px] border-border-strong bg-canvas shadow-overlay"
        style="width: 390px; height: 780px;"
      >
        <div class="h-full overflow-y-auto">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  attr :rows, :list, required: true
  attr :selected_id, :string, required: true

  defp mobile_list(assigns) do
    ~H"""
    <.stack space="none" class="bg-canvas pb-cluster">
      <.mobile_topbar />
      <.mobile_toolbar />
      <.stack space="tight" class="px-related pt-related">
        <.mobile_card :for={row <- @rows} row={row} selected={row.id == @selected_id} />
      </.stack>
    </.stack>
    """
  end

  defp mobile_topbar(assigns) do
    ~H"""
    <header class="sticky top-0 z-10 flex items-center justify-between gap-related border-b border-border-subtle bg-surface px-related py-related">
      <h1 class="text-base font-heading font-semibold tracking-tight text-text">
        Media
      </h1>
      <span class="text-xs text-text-subtle">1,847</span>
    </header>
    """
  end

  defp mobile_toolbar(assigns) do
    ~H"""
    <div class="grid gap-related border-b border-border-subtle bg-surface px-related py-related">
      <div class="flex items-center gap-tight">
        <div class="relative grow">
          <Lucideicons.search class="absolute left-2.5 top-1/2 size-icon-sm -translate-y-1/2 text-text-subtle" />
          <input
            type="text"
            placeholder="Search…"
            class="h-9 w-full rounded-control border border-border bg-surface-inset pl-8 pr-2 text-sm text-text placeholder:text-text-subtle"
          />
        </div>
        <button
          type="button"
          class="grid h-9 w-9 shrink-0 place-items-center rounded-control border border-border bg-surface-raised text-text"
          aria-label="Filter"
        >
          <Lucideicons.sliders class="size-icon-sm" />
        </button>
      </div>
      <div class="-mx-related overflow-x-auto px-related">
        <div class="flex items-center gap-tight whitespace-nowrap">
          <.filter_chip label="Media" value="Video" />
          <.filter_chip label="Match" value="No match" />
          <.filter_chip label="Library" value="Sci-Fi" />
        </div>
      </div>
    </div>
    """
  end

  attr :row, :map, required: true
  attr :selected, :boolean, default: false

  defp mobile_card(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "grid gap-tight rounded-control border bg-surface p-related text-left",
        @selected && "border-accent",
        !@selected && "border-border-subtle"
      ]}
    >
      <div class="flex items-center gap-related min-w-0">
        <.media_type_glyph type={@row.media_type} />
        <span class="truncate text-sm font-medium text-text grow">
          {file_name(@row.path)}
        </span>
      </div>

      <div class="flex items-center gap-related min-w-0 pl-9">
        <.content_type_chip type={@row.content_type} />
        <span class="truncate text-xs text-text-muted grow">{matched_content_inline(@row)}</span>
        <.clubs_avatars clubs={@row.clubs} />
      </div>
    </button>
    """
  end

  attr :media, :map, required: true

  defp mobile_detail_sheet(assigns) do
    ~H"""
    <.stack space="none" class="bg-surface">
      <header class="sticky top-0 z-10 grid gap-related border-b border-border-subtle bg-surface px-related py-related">
        <div class="flex items-center gap-related">
          <button
            type="button"
            class="rounded-control p-1 text-text-subtle hover:text-text"
            aria-label="Back"
          >
            <Lucideicons.arrow_left class="size-icon" />
          </button>
          <.media_type_glyph type={@media.media_type} />
          <span class="grow truncate text-sm font-medium text-text" title={file_name(@media.path)}>
            {file_name(@media.path)}
          </span>
        </div>
        <.cluster space="related">
          <.button id="m-drawer-play" variant="accent" size="md" emphasis class="grow">
            <:icon><.dynamic_icon name={play_icon(@media.media_type)} class="size-icon-sm" /></:icon>
            {play_label(@media.media_type)}
          </.button>
          <.button
            id="m-drawer-delete"
            variant="ghost"
            size="md"
            class="text-danger hover:bg-danger-bg hover:text-danger"
          >
            <:icon><Lucideicons.trash_2 /></:icon>
            Delete
          </.button>
        </.cluster>
      </header>

      <div class="grid gap-cluster p-cluster">
        <.content_hero media={@media} />

        <.drawer_section :if={@media.media_type == :video} label="Video">
          <.dl>
            <.dl_badge_row label="Resolution">
              <.resolution_label_cell resolution={@media.resolution} />
            </.dl_badge_row>
            <.dl_badge_row label="Codec">
              <.spec_badge>{@media.video_codec}</.spec_badge>
            </.dl_badge_row>
            <.dl_badge_row label="Container">
              <.spec_badge>{@media.container}</.spec_badge>
            </.dl_badge_row>
            <.dl_row label="Frame rate" value={@media.framerate} />
            <.dl_badge_row :if={@media.hdr} label="Range">
              <.spec_badge>HDR10</.spec_badge>
            </.dl_badge_row>
          </.dl>
        </.drawer_section>

        <.drawer_section :if={@media.audio_tracks != []} label={"Audio (#{length(@media.audio_tracks)})"}>
          <ul class="grid gap-tight">
            <li
              :for={track <- @media.audio_tracks}
              class="flex items-center justify-between gap-related text-sm"
            >
              <.inline space="related" class="min-w-0">
                <span class="text-base leading-none">{language_flag(track.language)}</span>
                <span class="truncate text-text">{language_label(track.language)}</span>
              </.inline>
              <.cluster space="tight" class="shrink-0">
                <.spec_badge>{track.codec}</.spec_badge>
                <.spec_badge>{track.channels}</.spec_badge>
              </.cluster>
            </li>
          </ul>
        </.drawer_section>

        <.drawer_section :if={@media.subtitle_tracks != []} label={"Subtitles (#{length(@media.subtitle_tracks)})"}>
          <ul class="grid gap-tight">
            <li
              :for={track <- @media.subtitle_tracks}
              class="flex items-center justify-between gap-related text-sm"
            >
              <.inline space="related" class="min-w-0">
                <span class="text-base leading-none">{language_flag(track.language)}</span>
                <span class="truncate text-text">{language_label(track.language)}</span>
              </.inline>
              <.spec_badge :if={track.forced}>Forced</.spec_badge>
              <.spec_badge :if={track.default && !track.forced}>Default</.spec_badge>
            </li>
          </ul>
        </.drawer_section>

        <.drawer_section label="File">
          <.dl>
            <.dl_row label="Path" value={@media.path} mono />
            <.dl_row label="Size" value={@media.size} />
            <.dl_row label="Imported" value={@media.imported_at} />
            <.dl_row label="Modified" value={@media.modified_at} />
          </.dl>
        </.drawer_section>
      </div>
    </.stack>
    """
  end

  # ---------------------------------------------------------------------------
  # Flat tab (default)
  # ---------------------------------------------------------------------------

  def render(assigns) do
    assigns =
      assigns
      |> assign(rows: media_rows())
      |> assign(selected: hd(media_rows()))

    ~H"""
    <.theme_frame>
      <.page space="cluster" width="full">
        <.eyebrow_header
          eyebrow="Admin · Media"
          title="Media browser"
          description="Every Media file on the instance. Filter, drill, delete."
        />

        <.view_toggle current={:flat} />
        <.toolbar />

        <div class="grid gap-cluster lg:grid-cols-[minmax(0,1fr)_28rem]">
          <.card surface="default" padding="none" class="overflow-hidden">
            <.table class="min-w-full">
              <.flat_table_head />
              <.table_body>
                <.flat_media_row :for={row <- @rows} row={row} selected={row.id == @selected.id} />
              </.table_body>
            </.table>
          </.card>

          <.detail_drawer media={@selected} />
        </div>
      </.page>
    </.theme_frame>
    """
  end

  # ---------------------------------------------------------------------------
  # Frame, header, view toggle
  # ---------------------------------------------------------------------------

  slot :inner_block, required: true

  defp theme_frame(assigns) do
    ~H"""
    <div class="theme-wc dark -m-8 min-h-screen bg-canvas text-text">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp eyebrow_header(assigns) do
    ~H"""
    <header>
      <.stack space="tight">
        <.cluster space="related">
          <.badge variant="accent" size="sm">Brainstorm / temporary</.badge>
          <span class="text-xs font-semibold uppercase tracking-[0.18em] text-text-subtle">
            {@eyebrow}
          </span>
        </.cluster>
        <h1 class="text-3xl font-heading font-semibold tracking-tight text-text">
          {@title}
        </h1>
        <p class="max-w-readable text-sm leading-6 text-text-muted">{@description}</p>
      </.stack>
    </header>
    """
  end

  attr :current, :atom, required: true

  defp view_toggle(assigns) do
    ~H"""
    <div class="inline-flex w-fit items-center gap-0 rounded-control border border-border bg-surface-inset p-0.5">
      <.view_toggle_btn label="Flat" icon={:list} active={@current == :flat} />
      <.view_toggle_btn label="Grouped" icon={:folder_tree} active={@current == :grouped} />
    </div>
    """
  end

  attr :label, :string, required: true
  attr :icon, :atom, required: true
  attr :active, :boolean, required: true

  defp view_toggle_btn(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "inline-flex h-7 items-center gap-tight rounded-[calc(var(--radius-control)-2px)] px-3 text-xs font-medium transition",
        @active && "bg-surface-raised text-text shadow-card",
        !@active && "text-text-muted hover:text-text"
      ]}
    >
      <.dynamic_icon name={@icon} class="size-icon-sm" />
      {@label}
    </button>
    """
  end

  # ---------------------------------------------------------------------------
  # Toolbar
  # ---------------------------------------------------------------------------

  defp toolbar(assigns) do
    ~H"""
    <.card surface="default" padding="cluster">
      <.stack space="related">
        <.cluster space="related">
          <div class="relative grow min-w-[18rem]">
            <Lucideicons.search class="absolute left-3 top-1/2 size-icon-sm -translate-y-1/2 text-text-subtle" />
            <input
              type="text"
              placeholder="Search file name or content…"
              class="h-control-md w-full rounded-control border border-border bg-surface-inset pl-9 pr-3 text-sm text-text placeholder:text-text-subtle focus:border-border-focus focus:outline-none focus:ring-2 focus:ring-focus-ring"
            />
          </div>

          <.button id="add-filter-btn" variant="secondary" size="md">
            <:icon><Lucideicons.plus /></:icon>
            Filter
          </.button>

          <div class="ml-auto flex items-center gap-related">
            <.dropdown_button label="Sort: Last import" icon={:arrow_down_wide_narrow} />
            <.dropdown_button label="Columns" icon={:columns_3} />
          </div>
        </.cluster>

        <.cluster space="tight">
          <.filter_chip label="Media" value="Video" />
          <.filter_chip label="Match" value="No match" />
          <.filter_chip label="Library" value="Movie Night · Sci-Fi" />
          <button
            type="button"
            class="inline-flex h-7 items-center px-2 text-xs text-text-subtle hover:text-text"
          >
            Clear all
          </button>
        </.cluster>

        <div class="flex items-center justify-between text-xs text-text-subtle">
          <span>1,847 Media · showing 12</span>
          <span class="inline-flex items-center gap-tight">
            <Lucideicons.infinity class="size-icon-sm" /> Virtualized
          </span>
        </div>
      </.stack>
    </.card>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp filter_chip(assigns) do
    ~H"""
    <span class="inline-flex h-7 items-center gap-tight rounded-full border border-accent-border bg-accent-bg pl-3 pr-1.5 text-xs text-accent">
      <span class="text-accent">{@label}:</span>
      <strong class="font-semibold">{@value}</strong>
      <button
        type="button"
        class="grid size-4 place-items-center rounded-full hover:bg-accent-bg"
        aria-label={"Remove filter #{@label}"}
      >
        <Lucideicons.x class="size-3" />
      </button>
    </span>
    """
  end

  attr :label, :string, required: true
  attr :icon, :atom, required: true

  defp dropdown_button(assigns) do
    ~H"""
    <button
      type="button"
      class="inline-flex h-control-md items-center gap-tight rounded-control border border-border bg-surface-raised px-3 text-sm text-text-muted hover:text-text"
    >
      <.dynamic_icon name={@icon} class="size-icon-sm" />
      <span>{@label}</span>
      <Lucideicons.chevron_down class="size-icon-sm text-text-subtle" />
    </button>
    """
  end

  # ---------------------------------------------------------------------------
  # Flat table — File primary, Matched Content secondary
  # ---------------------------------------------------------------------------

  defp flat_table_head(assigns) do
    ~H"""
    <.table_header>
      <.table_row>
        <.table_head>File</.table_head>
        <.table_head class="w-[6rem]">Type</.table_head>
        <.table_head>Matched Content</.table_head>
        <.table_head class="w-[7rem]">Clubs</.table_head>
        <.table_head class="w-[6rem]">Audio</.table_head>
        <.table_head class="w-[6rem]">Subtitles</.table_head>
        <.table_head class="w-[5rem]">Resolution</.table_head>
        <.table_head class="w-[5rem]">Imported</.table_head>
      </.table_row>
    </.table_header>
    """
  end

  attr :row, :map, required: true
  attr :selected, :boolean, default: false

  defp flat_media_row(assigns) do
    ~H"""
    <.table_row selected={@selected} class="[&>td]:py-2.5">
      <.table_cell><.flat_file_cell row={@row} /></.table_cell>
      <.table_cell><.content_type_chip type={@row.content_type} /></.table_cell>
      <.table_cell><.flat_matched_content_cell row={@row} /></.table_cell>
      <.table_cell><.clubs_avatars clubs={@row.clubs} /></.table_cell>
      <.table_cell><.flag_strip langs={@row.audio_languages} /></.table_cell>
      <.table_cell><.flag_strip langs={@row.subtitle_languages} /></.table_cell>
      <.table_cell><.resolution_label_cell resolution={@row.resolution} /></.table_cell>
      <.table_cell><.relative_time iso={@row.imported_at} /></.table_cell>
    </.table_row>
    """
  end

  attr :row, :map, required: true

  defp flat_file_cell(assigns) do
    ~H"""
    <div class="flex items-center gap-related min-w-0">
      <.media_type_glyph type={@row.media_type} />
      <span class="block truncate text-sm font-medium text-text">{file_name(@row.path)}</span>
    </div>
    """
  end

  attr :type, :atom, required: true

  defp media_type_glyph(assigns) do
    icon =
      case assigns.type do
        :video -> :film
        :ebook -> :book_open
        :audiobook -> :headphones
      end

    assigns = assign(assigns, icon: icon)

    ~H"""
    <span class="grid size-7 shrink-0 place-items-center rounded-control border border-border-subtle bg-surface-inset text-text-muted">
      <.dynamic_icon name={@icon} class="size-icon-sm" />
    </span>
    """
  end

  attr :row, :map, required: true

  defp flat_matched_content_cell(assigns) do
    ~H"""
    <div class="min-w-0">
      <span class="block truncate text-sm text-text-muted">{matched_content_inline(@row)}</span>
    </div>
    """
  end

  defp matched_content_inline(%{match_status: :no_match}), do: "—"
  defp matched_content_inline(%{match_status: :failed}), do: "—"

  defp matched_content_inline(%{content_title: title, content_sub: nil}), do: title

  defp matched_content_inline(%{content_title: title, content_sub: sub}),
    do: "#{title} · #{sub}"

  attr :clubs, :list, required: true

  defp clubs_avatars(assigns) do
    ~H"""
    <div :if={@clubs == []} class="text-xs text-text-subtle">—</div>
    <.avatar_group :if={@clubs != []} avatars={@clubs} avatar_size="xs" />
    """
  end

  # ---------------------------------------------------------------------------
  # Grouped — Content band + Media table
  # ---------------------------------------------------------------------------

  attr :group, :map, required: true
  attr :selected_id, :string, required: true

  defp content_block(assigns) do
    ~H"""
    <.card surface="default" padding="none" class="overflow-hidden">
      <.content_band group={@group} />

      <.table class="min-w-full border-t border-border-subtle">
        <.grouped_media_table_head />
        <.table_body>
          <.grouped_media_row
            :for={row <- @group.media}
            row={row}
            show_episode_prefix={@group.content_type == :tv_show}
            selected={row.id == @selected_id}
          />
        </.table_body>
      </.table>
    </.card>
    """
  end

  attr :group, :map, required: true

  defp content_band(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-related px-cluster py-related">
      <.content_type_chip type={@group.content_type} />

      <h2 class="text-sm font-medium text-text">{@group.title}</h2>

      <span :if={@group.sub} class="text-xs text-text-subtle">
        · {@group.sub}
      </span>

      <.cluster :if={@group.missing_count > 0 or @group.failed_count > 0} space="tight">
        <.warning_chip :if={@group.missing_count > 0}>
          Missing {@group.missing_count}
        </.warning_chip>
        <.badge :if={@group.failed_count > 0} variant="danger" size="sm">
          Failed {@group.failed_count}
        </.badge>
      </.cluster>

      <div class="ml-auto flex items-center gap-cluster text-xs text-text-muted">
        <.libraries_inline libraries={@group.libraries} />
        <span class="text-text-subtle">·</span>
        <span>
          <strong class="font-medium text-text">{length(@group.media)}</strong>
          {(length(@group.media) == 1 && "Media") || "Media"}
        </span>
      </div>
    </div>
    """
  end

  attr :type, :atom, required: true

  defp content_type_chip(assigns) do
    label =
      case assigns.type do
        :movie -> "Movie"
        :tv_show -> "TV Show"
        :tv_show_episode -> "TV Show"
        :book -> "Book"
      end

    assigns = assign(assigns, label: label)

    ~H"""
    <span class="inline-flex h-5 items-center rounded-full border border-border-subtle bg-surface-inset px-related text-[0.65rem] font-semibold uppercase tracking-[0.12em] text-text-muted">
      {@label}
    </span>
    """
  end

  attr :libraries, :list, required: true

  defp libraries_inline(assigns) do
    ~H"""
    <span :if={@libraries == []} class="text-text-subtle">Not in any Library</span>
    <span :if={@libraries != []} class="inline-flex items-center gap-tight">
      <Lucideicons.library class="size-icon-sm text-text-subtle" />
      <span>
        <strong class="font-medium text-text">{length(@libraries)}</strong>
        {(length(@libraries) == 1 && "library") || "libraries"}:
      </span>
      <span class="text-text-muted">{libraries_summary(@libraries)}</span>
    </span>
    """
  end

  defp grouped_media_table_head(assigns) do
    ~H"""
    <.table_header>
      <.table_row>
        <.table_head class="w-[3px] p-0"><span class="sr-only">Status</span></.table_head>
        <.table_head>File</.table_head>
        <.table_head class="w-[6rem]">Resolution</.table_head>
        <.table_head class="w-[6rem] text-right">Size</.table_head>
        <.table_head class="w-[7rem]">Tracks</.table_head>
        <.table_head class="w-[7rem]">Audio</.table_head>
        <.table_head class="w-[7rem]">Subtitles</.table_head>
        <.table_head class="w-[6rem]">Imported</.table_head>
      </.table_row>
    </.table_header>
    """
  end

  attr :row, :map, required: true
  attr :show_episode_prefix, :boolean, default: false
  attr :selected, :boolean, default: false

  defp grouped_media_row(assigns) do
    ~H"""
    <.table_row selected={@selected} class="min-h-touch-target [&>td]:py-2">
      <td class={["w-[3px] p-0", status_rail_class(@row.match_status)]} aria-hidden="true"></td>
      <.table_cell>
        <.grouped_file_cell row={@row} show_episode_prefix={@show_episode_prefix} />
      </.table_cell>
      <.table_cell>
        <.resolution_label_cell resolution={@row.resolution} />
      </.table_cell>
      <.table_cell class="text-right font-mono text-xs text-text-muted">
        {@row.size}
      </.table_cell>
      <.table_cell><.tracks_counts row={@row} /></.table_cell>
      <.table_cell><.flag_strip langs={@row.audio_languages} /></.table_cell>
      <.table_cell><.flag_strip langs={@row.subtitle_languages} /></.table_cell>
      <.table_cell><.relative_time iso={@row.imported_at} /></.table_cell>
    </.table_row>
    """
  end

  # ---------------------------------------------------------------------------
  # Unmatched block (grouped view)
  # ---------------------------------------------------------------------------

  attr :block, :map, required: true

  defp unmatched_block(assigns) do
    ~H"""
    <.card surface="default" padding="none" class="overflow-hidden border-warning-border">
      <div class="flex flex-wrap items-center gap-related px-cluster py-related bg-warning-bg">
        <span class="inline-flex h-5 items-center rounded-full border border-warning-border bg-warning-bg px-related text-[0.65rem] font-semibold uppercase tracking-[0.12em] text-warning">
          Unmatched
        </span>
        <h2 class="text-sm font-medium text-text">Files that couldn't be matched to Content</h2>
        <div class="ml-auto text-xs text-text-muted">
          <strong class="font-medium text-text">{length(@block.media)}</strong> files
        </div>
      </div>

      <.table class="min-w-full border-t border-warning-border">
        <.grouped_media_table_head />
        <.table_body>
          <.grouped_media_row :for={row <- @block.media} row={row} />
        </.table_body>
      </.table>
    </.card>
    """
  end

  # ---------------------------------------------------------------------------
  # Shared cell + chrome primitives
  # ---------------------------------------------------------------------------

  attr :row, :map, required: true
  attr :show_episode_prefix, :boolean, default: false

  defp grouped_file_cell(assigns) do
    ~H"""
    <div class="min-w-0">
      <.stack space="tight">
        <div class="flex items-baseline gap-tight min-w-0">
          <span
            :if={@show_episode_prefix && @row.episode_code}
            class="shrink-0 font-mono text-xs text-text-subtle"
          >
            {@row.episode_code}
          </span>
          <span class="truncate text-sm font-medium text-text">{file_name(@row.path)}</span>
        </div>
        <div class="truncate text-xs text-text-subtle">{secondary_meta_line(@row)}</div>
      </.stack>
    </div>
    """
  end

  defp libraries_summary([first | rest]) when rest == [], do: first
  defp libraries_summary([first | rest]), do: "#{first}, +#{length(rest)}"
  defp libraries_summary([]), do: ""

  attr :row, :map, required: true

  defp tracks_counts(assigns) do
    audio = length(assigns.row.audio_tracks || [])
    subs = length(assigns.row.subtitle_tracks || [])

    assigns = assigns |> assign(audio: audio) |> assign(subs: subs)

    ~H"""
    <div :if={@audio == 0 and @subs == 0} class="text-xs text-text-subtle">—</div>
    <div :if={@audio > 0 or @subs > 0} class="inline-flex items-center gap-related text-xs text-text-muted whitespace-nowrap">
      <span class="inline-flex items-center gap-tight">
        <Lucideicons.audio_lines class="size-icon-sm text-text-subtle" />
        <span class="font-medium text-text">{@audio}</span>
      </span>
      <span class="inline-flex items-center gap-tight">
        <Lucideicons.captions class="size-icon-sm text-text-subtle" />
        <span class="font-medium text-text">{@subs}</span>
      </span>
    </div>
    """
  end

  attr :langs, :list, required: true

  defp flag_strip(assigns) do
    ~H"""
    <div :if={@langs == []} class="text-xs text-text-subtle">—</div>
    <div :if={@langs != []} class="flex items-center gap-tight whitespace-nowrap">
      <span
        :for={lang <- Enum.take(@langs, 3)}
        title={language_label(lang)}
        class="text-base leading-none"
      >
        {language_flag(lang)}
      </span>
      <span :if={length(@langs) > 3} class="text-xs text-text-subtle">
        +{length(@langs) - 3}
      </span>
    </div>
    """
  end

  attr :resolution, :atom, required: true

  defp resolution_label_cell(assigns) do
    ~H"""
    <.badge :if={@resolution} variant="muted" size="sm">
      {resolution_badge_label(@resolution)}
    </.badge>
    <span :if={!@resolution} class="text-xs text-text-subtle">—</span>
    """
  end

  defp resolution_badge_label(:uhd_4k), do: "4K"
  defp resolution_badge_label(:hd_1080p), do: "1080p"
  defp resolution_badge_label(:hd_720p), do: "720p"
  defp resolution_badge_label(:sd), do: "SD"
  defp resolution_badge_label(nil), do: nil

  attr :iso, :string, required: true

  defp relative_time(assigns) do
    ~H"""
    <span class="text-xs text-text-subtle whitespace-nowrap">{humanize_time(@iso)}</span>
    """
  end

  defp status_rail_class(:no_match), do: "bg-warning"
  defp status_rail_class(:failed), do: "bg-danger"
  defp status_rail_class(_), do: ""

  slot :inner_block, required: true

  defp warning_chip(assigns) do
    ~H"""
    <span class="inline-flex h-5 items-center rounded-full border border-warning-border bg-warning-bg px-related text-xs font-medium text-warning">
      {render_slot(@inner_block)}
    </span>
    """
  end

  # ---------------------------------------------------------------------------
  # Detail drawer
  # ---------------------------------------------------------------------------

  attr :media, :map, required: true

  defp detail_drawer(assigns) do
    ~H"""
    <aside class="grid h-fit overflow-hidden rounded-card border border-border bg-surface shadow-card">
      <.drawer_hero media={@media} />

      <div class="grid gap-cluster p-cluster">
        <.content_hero media={@media} />

        <.drawer_section :if={@media.media_type == :video} label="Video">
          <.dl>
            <.dl_badge_row label="Resolution">
              <.resolution_label_cell resolution={@media.resolution} />
            </.dl_badge_row>
            <.dl_badge_row label="Codec">
              <.spec_badge>{@media.video_codec}</.spec_badge>
            </.dl_badge_row>
            <.dl_badge_row label="Container">
              <.spec_badge>{@media.container}</.spec_badge>
            </.dl_badge_row>
            <.dl_row label="Frame rate" value={@media.framerate} />
            <.dl_badge_row :if={@media.hdr} label="Range">
              <.spec_badge>HDR10</.spec_badge>
            </.dl_badge_row>
          </.dl>
        </.drawer_section>

        <.drawer_section :if={@media.audio_tracks != []} label={"Audio (#{length(@media.audio_tracks)})"}>
          <ul class="grid gap-tight">
            <li
              :for={track <- @media.audio_tracks}
              class="flex items-center justify-between gap-related text-sm"
            >
              <.inline space="related" class="min-w-0">
                <span class="text-base leading-none">{language_flag(track.language)}</span>
                <span class="truncate text-text">{language_label(track.language)}</span>
              </.inline>
              <.cluster space="tight" class="shrink-0">
                <.spec_badge>{track.codec}</.spec_badge>
                <.spec_badge>{track.channels}</.spec_badge>
              </.cluster>
            </li>
          </ul>
        </.drawer_section>

        <.drawer_section :if={@media.subtitle_tracks != []} label={"Subtitles (#{length(@media.subtitle_tracks)})"}>
          <ul class="grid gap-tight">
            <li
              :for={track <- @media.subtitle_tracks}
              class="flex items-center justify-between gap-related text-sm"
            >
              <.inline space="related" class="min-w-0">
                <span class="text-base leading-none">{language_flag(track.language)}</span>
                <span class="truncate text-text">{language_label(track.language)}</span>
              </.inline>
              <.spec_badge :if={track.forced}>Forced</.spec_badge>
              <.spec_badge :if={track.default && !track.forced}>Default</.spec_badge>
            </li>
          </ul>
        </.drawer_section>

        <.drawer_section label="File">
          <.dl>
            <.dl_row label="Path" value={@media.path} mono />
            <.dl_row label="Size" value={@media.size} />
            <.dl_row label="Imported" value={@media.imported_at} />
            <.dl_row label="Modified" value={@media.modified_at} />
          </.dl>
        </.drawer_section>
      </div>
    </aside>
    """
  end

  attr :media, :map, required: true

  defp content_hero(assigns) do
    ~H"""
    <.stack space="group">
      <div class="grid grid-cols-[6rem_minmax(0,1fr)] items-start gap-cluster">
        <.typographic_poster media={@media} />

        <.stack space="tight" class="min-w-0 self-center">
          <button
            type="button"
            class="text-left text-xl font-heading font-semibold leading-tight tracking-tight text-text hover:text-accent"
            title="Open Content page"
          >
            {content_title_with_fallback(@media)}
          </button>

          <ul class="flex flex-wrap items-center gap-related text-sm text-text-muted">
            <li :for={{item, index} <- Enum.with_index(content_meta_items(@media))} class="flex items-center gap-related">
              <span :if={index > 0} aria-hidden="true">·</span>
              <span>{item}</span>
            </li>
          </ul>
        </.stack>
      </div>

      <.cluster :if={@media.libraries != []} space="tight">
        <.badge :for={lib <- @media.libraries} variant="secondary" size="sm">
          <:icon><Lucideicons.library /></:icon>
          <span class="max-w-[14rem] truncate">{lib}</span>
        </.badge>
      </.cluster>
      <p :if={@media.libraries == []} class="text-sm text-text-subtle">
        Not in any Library.
      </p>
    </.stack>
    """
  end

  attr :media, :map, required: true

  defp typographic_poster(assigns) do
    ~H"""
    <button
      type="button"
      class="block w-full overflow-hidden rounded-control border border-border-subtle shadow-card hover:border-border-strong"
      aria-label="Open Content page"
    >
      <.tmdb_poster path={nil} size="w154" alt={content_title_with_fallback(@media)} />
    </button>
    """
  end

  # Metadata middot list under the title — choose the right hierarchy per content type
  defp content_meta_items(%{content_type: :movie} = media) do
    ["Movie", content_year(media)] |> Enum.reject(&is_nil/1)
  end

  defp content_meta_items(%{content_type: :tv_show_episode, content_sub: sub}) when is_binary(sub) do
    # sub looks like "S01E02 · The Big Empty"
    case String.split(sub, " · ", parts: 2) do
      [code, title] -> ["TV Show episode", code, title]
      [code] -> ["TV Show episode", code]
    end
  end

  defp content_meta_items(%{content_type: :tv_show_episode}), do: ["TV Show episode"]

  defp content_meta_items(%{content_type: :book, content_sub: sub}) when is_binary(sub) do
    # sub looks like "Isaac Asimov" or "Isaac Asimov · Audiobook"
    author = sub |> String.split(" · ") |> List.first()
    ["Book", author]
  end

  defp content_meta_items(%{content_type: :book}), do: ["Book"]

  defp content_meta_items(_), do: []

  defp content_type_icon(:movie), do: :clapperboard
  defp content_type_icon(:tv_show), do: :tv
  defp content_type_icon(:tv_show_episode), do: :tv
  defp content_type_icon(:book), do: :book_open

  defp content_year(%{content_type: type, content_sub: sub})
       when type in [:movie] and is_binary(sub),
       do: sub

  defp content_year(_), do: nil

  defp content_episode_sub(%{content_type: type, content_sub: sub})
       when type in [:tv_show_episode, :book] and is_binary(sub),
       do: sub

  defp content_episode_sub(_), do: nil

  attr :media, :map, required: true

  defp drawer_hero(assigns) do
    ~H"""
    <header class="grid gap-group border-b border-border-subtle p-cluster">
      <div class="flex items-center gap-related">
        <span class="grid size-9 shrink-0 place-items-center rounded-control border border-border-subtle bg-surface-inset text-text-muted">
          <.dynamic_icon name={media_type_icon_name(@media.media_type)} class="size-icon" />
        </span>
        <.stack space="tight" class="min-w-0 grow">
          <span class="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-text-subtle">
            {humanize_type(@media.media_type)} file
          </span>
          <span
            class="truncate font-mono text-sm text-text"
            title={file_name(@media.path)}
          >
            {file_name(@media.path)}
          </span>
        </.stack>
        <button
          type="button"
          class="shrink-0 rounded-control p-1 text-text-subtle hover:bg-surface-raised hover:text-text"
          aria-label="Close drawer"
        >
          <Lucideicons.x class="size-icon-sm" />
        </button>
      </div>
      <.cluster space="related">
        <.button id="drawer-play" variant="accent" size="md" emphasis>
          <:icon><.dynamic_icon name={play_icon(@media.media_type)} class="size-icon-sm" /></:icon>
          {play_label(@media.media_type)}
        </.button>
        <.button id="drawer-delete" variant="ghost" size="md" class="text-danger hover:bg-danger-bg hover:text-danger">
          <:icon><Lucideicons.trash_2 /></:icon>
          Delete
        </.button>
      </.cluster>
    </header>
    """
  end

  defp media_type_icon_name(:video), do: :film
  defp media_type_icon_name(:ebook), do: :book_open
  defp media_type_icon_name(:audiobook), do: :headphones

  defp play_icon(:ebook), do: :book_open
  defp play_icon(_), do: :play

  defp play_label(:ebook), do: "Read"
  defp play_label(_), do: "Play"

  attr :status, :atom, required: true

  defp match_status_badge(assigns) do
    case assigns.status do
      :matched ->
        ~H"""
        <.badge variant="success" size="sm">Matched</.badge>
        """

      :no_match ->
        ~H"""
        <.warning_chip>No match</.warning_chip>
        """

      :failed ->
        ~H"""
        <.badge variant="danger" size="sm">Failed</.badge>
        """
    end
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp drawer_section(assigns) do
    ~H"""
    <section>
      <.stack space="related">
        <h3 class="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-text-subtle">
          {@label}
        </h3>
        {render_slot(@inner_block)}
      </.stack>
    </section>
    """
  end

  slot :inner_block, required: true

  defp dl(assigns) do
    ~H"""
    <dl class="grid grid-cols-[7rem_minmax(0,1fr)] items-center gap-x-related gap-y-related text-sm">
      {render_slot(@inner_block)}
    </dl>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :mono, :boolean, default: false

  defp dl_row(assigns) do
    ~H"""
    <dt class="text-text-subtle">{@label}</dt>
    <dd class={[
      "min-w-0 break-words text-text",
      @mono && "font-mono text-xs text-text-muted"
    ]}>
      {@value}
    </dd>
    """
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp dl_badge_row(assigns) do
    ~H"""
    <dt class="text-text-subtle self-center">{@label}</dt>
    <dd class="min-w-0 self-center">
      {render_slot(@inner_block)}
    </dd>
    """
  end

  slot :inner_block, required: true

  defp spec_badge(assigns) do
    ~H"""
    <.badge variant="muted" size="sm">{render_slot(@inner_block)}</.badge>
    """
  end

  # ---------------------------------------------------------------------------
  # Small helpers
  # ---------------------------------------------------------------------------

  attr :name, :atom, required: true
  attr :class, :string, default: "size-icon"

  defp dynamic_icon(assigns) do
    ~H"""
    {apply(Lucideicons, @name, [%{class: @class, __changed__: %{}}])}
    """
  end

  defp file_name(path), do: Path.basename(path)

  defp humanize_type(:video), do: "Video"
  defp humanize_type(:ebook), do: "Ebook"
  defp humanize_type(:audiobook), do: "Audiobook"

  defp humanize_content_type(:movie), do: "Movie"
  defp humanize_content_type(:tv_show), do: "TV Show"
  defp humanize_content_type(:tv_show_episode), do: "TV Show Episode"
  defp humanize_content_type(:book), do: "Book"

  defp content_title_with_fallback(%{match_status: :matched, content_title: title}), do: title
  defp content_title_with_fallback(%{match_status: :no_match}), do: "Unmatched"
  defp content_title_with_fallback(%{match_status: :failed}), do: "Failed"

  defp content_sub_label(%{content_type: :tv_show_episode}), do: "Episode"
  defp content_sub_label(%{content_type: :movie}), do: "Year"
  defp content_sub_label(%{content_type: :book}), do: "Author"
  defp content_sub_label(_), do: "Detail"

  # Grouped-view secondary line — codec + container only;
  # resolution and size live in their own columns
  defp secondary_meta_line(%{media_type: :video} = row) do
    [row.video_codec, row.container]
    |> Enum.reject(&(&1 in [nil, "—"]))
    |> Enum.join(" · ")
  end

  defp secondary_meta_line(row) do
    [row.container]
    |> Enum.reject(&(&1 in [nil, "—"]))
    |> Enum.join(" · ")
  end

  defp resolution_label(:uhd_4k), do: "2160p"
  defp resolution_label(:hd_1080p), do: "1080p"
  defp resolution_label(:hd_720p), do: "720p"
  defp resolution_label(:sd), do: "SD"
  defp resolution_label(nil), do: nil

  # Mock relative-time: parse "YYYY-MM-DD HH:MM" against a fixed "now".
  @now ~N[2026-05-21 12:00:00]
  defp humanize_time(iso) when is_binary(iso) do
    case NaiveDateTime.from_iso8601(iso <> ":00") do
      {:ok, ndt} ->
        diff = NaiveDateTime.diff(@now, ndt, :second)
        cond do
          diff < 60 -> "just now"
          diff < 3600 -> "#{div(diff, 60)}m ago"
          diff < 86_400 -> "#{div(diff, 3600)}h ago"
          diff < 7 * 86_400 -> "#{div(diff, 86_400)}d ago"
          true -> "#{div(diff, 86_400)}d ago"
        end

      _ ->
        iso
    end
  end

  @language_country %{
    "en" => "GB",
    "fr" => "FR",
    "ja" => "JP",
    "es" => "ES",
    "de" => "DE",
    "it" => "IT",
    "pt" => "PT",
    "zh" => "CN",
    "ko" => "KR"
  }

  defp language_flag(code) do
    country = Map.get(@language_country, code, "UN")

    country
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(&(&1 + 127_397))
    |> List.to_string()
  end

  @language_label %{
    "en" => "English",
    "fr" => "French",
    "ja" => "Japanese",
    "es" => "Spanish",
    "de" => "German",
    "it" => "Italian",
    "pt" => "Portuguese",
    "zh" => "Chinese",
    "ko" => "Korean"
  }

  defp language_label(code), do: Map.get(@language_label, code, code)

  # ---------------------------------------------------------------------------
  # Mock data — flat
  # ---------------------------------------------------------------------------

  defp media_rows do
    [
      media_record(%{
        id: "m1",
        media_type: :video,
        content_type: :movie,
        match_status: :matched,
        path: "/mnt/media/movies/Dune.2021.2160p.HDR.mkv",
        content_title: "Dune",
        content_sub: "2021",
        libraries: ["Movie Night · Sci-Fi", "Anders · Watchlist", "Family Room · Saturday"],
        import_config: "filesystem-movies",
        size: "23.4 GB",
        container: "mkv",
        video_codec: "h265",
        framerate: "24 fps",
        resolution: :uhd_4k,
        hdr: true,
        audio_languages: ["en", "fr", "ja", "es"],
        subtitle_languages: ["en", "fr", "es", "de", "ja"],
        audio_tracks: [
          %{language: "en", codec: "TrueHD Atmos", channels: "7.1"},
          %{language: "fr", codec: "EAC3", channels: "5.1"},
          %{language: "ja", codec: "AAC", channels: "2.0"},
          %{language: "es", codec: "AAC", channels: "2.0"}
        ],
        subtitle_tracks: [
          %{language: "en", default: true, forced: false},
          %{language: "en", default: false, forced: true},
          %{language: "fr", default: false, forced: false},
          %{language: "es", default: false, forced: false},
          %{language: "de", default: false, forced: false},
          %{language: "ja", default: false, forced: false}
        ],
        imported_at: "2026-05-19 14:02"
      }),
      media_record(%{
        id: "m2",
        media_type: :video,
        content_type: :tv_show_episode,
        match_status: :matched,
        path: "/mnt/media/tv/The Expanse/S01E01.mkv",
        content_title: "The Expanse",
        content_sub: "S01E01 · Dulcinea",
        episode_code: "S01E01",
        libraries: ["Movie Night · Sci-Fi"],
        import_config: "filesystem-tv",
        size: "4.1 GB",
        container: "mkv",
        video_codec: "h264",
        framerate: "23.976 fps",
        resolution: :hd_1080p,
        hdr: false,
        audio_languages: ["en", "fr"],
        subtitle_languages: ["en", "fr", "es"],
        audio_tracks: [
          %{language: "en", codec: "DTS", channels: "5.1"},
          %{language: "fr", codec: "AC3", channels: "5.1"}
        ],
        subtitle_tracks: [
          %{language: "en", default: true, forced: false},
          %{language: "fr", default: false, forced: false},
          %{language: "es", default: false, forced: false}
        ],
        imported_at: "2026-05-19 13:51"
      }),
      media_record(%{
        id: "m3",
        media_type: :ebook,
        content_type: :book,
        match_status: :matched,
        path: "/mnt/media/books/Foundation.epub",
        content_title: "Foundation",
        content_sub: "Isaac Asimov",
        libraries: [],
        import_config: "filesystem-ebooks",
        size: "1.8 MB",
        container: "epub",
        video_codec: "—",
        framerate: "—",
        resolution: nil,
        hdr: false,
        audio_languages: [],
        subtitle_languages: [],
        audio_tracks: [],
        subtitle_tracks: [],
        imported_at: "2026-05-18 22:10"
      }),
      media_record(%{
        id: "m4",
        media_type: :audiobook,
        content_type: :book,
        match_status: :matched,
        path: "/mnt/media/audiobooks/Foundation/01.mp3",
        content_title: "Foundation",
        content_sub: "Isaac Asimov · Audiobook",
        libraries: ["Quiet Hours · Sci-Fi"],
        import_config: "filesystem-audiobooks",
        size: "412 MB",
        container: "mp3",
        video_codec: "—",
        framerate: "—",
        resolution: nil,
        hdr: false,
        audio_languages: ["en"],
        subtitle_languages: [],
        audio_tracks: [%{language: "en", codec: "MP3", channels: "2.0"}],
        subtitle_tracks: [],
        imported_at: "2026-05-18 22:09"
      }),
      media_record(%{
        id: "m5",
        media_type: :video,
        content_type: :movie,
        match_status: :matched,
        path: "/mnt/media/movies/Arrival.2016.1080p.mkv",
        content_title: "Arrival",
        content_sub: "2016",
        libraries: ["Movie Night · Sci-Fi", "Anders · Watchlist"],
        import_config: "filesystem-movies",
        size: "11.7 GB",
        container: "mkv",
        video_codec: "h264",
        framerate: "24 fps",
        resolution: :hd_1080p,
        hdr: false,
        audio_languages: ["en", "fr", "de"],
        subtitle_languages: ["en", "fr", "de", "es"],
        audio_tracks: [
          %{language: "en", codec: "DTS-HD MA", channels: "7.1"},
          %{language: "fr", codec: "DTS", channels: "5.1"},
          %{language: "de", codec: "AC3", channels: "5.1"}
        ],
        subtitle_tracks: [
          %{language: "en", default: true, forced: false},
          %{language: "fr", default: false, forced: false},
          %{language: "de", default: false, forced: false},
          %{language: "es", default: false, forced: false}
        ],
        imported_at: "2026-05-18 09:22"
      }),
      media_record(%{
        id: "m6",
        media_type: :video,
        content_type: :movie,
        match_status: :no_match,
        path: "/mnt/media/movies/unknown.title.2023.mkv",
        content_title: nil,
        content_sub: nil,
        libraries: [],
        import_config: "filesystem-movies",
        size: "8.3 GB",
        container: "mkv",
        video_codec: "h264",
        framerate: "24 fps",
        resolution: :hd_1080p,
        hdr: false,
        audio_languages: ["en"],
        subtitle_languages: [],
        audio_tracks: [%{language: "en", codec: "AAC", channels: "5.1"}],
        subtitle_tracks: [],
        imported_at: "2026-05-18 09:18"
      }),
      media_record(%{
        id: "m7",
        media_type: :video,
        content_type: :tv_show_episode,
        match_status: :matched,
        path: "/mnt/media/tv/The Expanse/S01E02.mkv",
        content_title: "The Expanse",
        content_sub: "S01E02 · The Big Empty",
        episode_code: "S01E02",
        libraries: ["Movie Night · Sci-Fi"],
        import_config: "filesystem-tv",
        size: "3.9 GB",
        container: "mkv",
        video_codec: "h264",
        framerate: "23.976 fps",
        resolution: :hd_1080p,
        hdr: false,
        audio_languages: ["en"],
        subtitle_languages: ["en", "fr"],
        audio_tracks: [%{language: "en", codec: "DTS", channels: "5.1"}],
        subtitle_tracks: [
          %{language: "en", default: true, forced: false},
          %{language: "fr", default: false, forced: false}
        ],
        imported_at: "2026-05-18 09:17"
      }),
      media_record(%{
        id: "m8",
        media_type: :video,
        content_type: :movie,
        match_status: :matched,
        path: "/mnt/media/movies/Blade Runner 2049.2017.mkv",
        content_title: "Blade Runner 2049",
        content_sub: "2017",
        libraries: ["Movie Night · Sci-Fi"],
        import_config: "filesystem-movies",
        size: "18.2 GB",
        container: "mkv",
        video_codec: "h265",
        framerate: "24 fps",
        resolution: :uhd_4k,
        hdr: true,
        audio_languages: ["en", "fr", "es", "it"],
        subtitle_languages: ["en", "fr", "es", "it", "de"],
        audio_tracks: [
          %{language: "en", codec: "TrueHD Atmos", channels: "7.1"},
          %{language: "fr", codec: "EAC3", channels: "5.1"},
          %{language: "es", codec: "EAC3", channels: "5.1"},
          %{language: "it", codec: "AC3", channels: "5.1"}
        ],
        subtitle_tracks: [
          %{language: "en", default: true, forced: false},
          %{language: "fr", default: false, forced: false},
          %{language: "es", default: false, forced: false},
          %{language: "it", default: false, forced: false},
          %{language: "de", default: false, forced: false}
        ],
        imported_at: "2026-05-17 11:01"
      }),
      media_record(%{
        id: "m9",
        media_type: :video,
        content_type: :movie,
        match_status: :failed,
        path: "/mnt/media/movies/corrupt_file.mkv",
        content_title: nil,
        content_sub: nil,
        libraries: [],
        import_config: "filesystem-movies",
        size: "0 B",
        container: "mkv",
        video_codec: "—",
        framerate: "—",
        resolution: nil,
        hdr: false,
        audio_languages: [],
        subtitle_languages: [],
        audio_tracks: [],
        subtitle_tracks: [],
        imported_at: "2026-05-17 10:50"
      }),
      media_record(%{
        id: "m10",
        media_type: :video,
        content_type: :movie,
        match_status: :matched,
        path: "/mnt/media/movies/Interstellar.2014.mkv",
        content_title: "Interstellar",
        content_sub: "2014",
        libraries: ["Family Room · Saturday"],
        import_config: "filesystem-movies",
        size: "21.0 GB",
        container: "mkv",
        video_codec: "h265",
        framerate: "24 fps",
        resolution: :uhd_4k,
        hdr: true,
        audio_languages: ["en", "fr", "de"],
        subtitle_languages: ["en", "fr", "de"],
        audio_tracks: [
          %{language: "en", codec: "DTS-HD MA", channels: "5.1"},
          %{language: "fr", codec: "AC3", channels: "5.1"},
          %{language: "de", codec: "AC3", channels: "5.1"}
        ],
        subtitle_tracks: [
          %{language: "en", default: true, forced: false},
          %{language: "fr", default: false, forced: false},
          %{language: "de", default: false, forced: false}
        ],
        imported_at: "2026-05-16 20:13"
      }),
      media_record(%{
        id: "m11",
        media_type: :video,
        content_type: :tv_show_episode,
        match_status: :matched,
        path: "/mnt/media/tv/The Expanse/S01E03.mkv",
        content_title: "The Expanse",
        content_sub: "S01E03 · Remember the Cant",
        episode_code: "S01E03",
        libraries: ["Movie Night · Sci-Fi"],
        import_config: "filesystem-tv",
        size: "1.2 GB",
        container: "mkv",
        video_codec: "h264",
        framerate: "23.976 fps",
        resolution: :hd_720p,
        hdr: false,
        audio_languages: ["en"],
        subtitle_languages: ["en"],
        audio_tracks: [%{language: "en", codec: "AAC", channels: "2.0"}],
        subtitle_tracks: [%{language: "en", default: true, forced: false}],
        imported_at: "2026-05-16 19:55"
      }),
      media_record(%{
        id: "m12",
        media_type: :video,
        content_type: :movie,
        match_status: :matched,
        path: "/mnt/media/movies/2001.A.Space.Odyssey.1968.avi",
        content_title: "2001: A Space Odyssey",
        content_sub: "1968",
        libraries: ["Anders · Watchlist"],
        import_config: "filesystem-movies",
        size: "1.6 GB",
        container: "avi",
        video_codec: "mpeg4",
        framerate: "24 fps",
        resolution: :sd,
        hdr: false,
        audio_languages: ["en"],
        subtitle_languages: [],
        audio_tracks: [%{language: "en", codec: "MP3", channels: "2.0"}],
        subtitle_tracks: [],
        imported_at: "2026-05-16 08:30"
      })
    ]
  end

  defp media_record(attrs) do
    libraries = Map.get(attrs, :libraries, [])

    base = %{
      episode_code: nil,
      imported_at: "2026-05-19 14:02",
      modified_at: "2026-05-18 22:09",
      import_trigger: "Scheduled",
      clubs: clubs_from_libraries(libraries)
    }

    Map.merge(base, attrs)
  end

  # Library strings look like "Movie Night · Sci-Fi" — the part before the
  # middot is the club name. Derive a stable `{id, name}` avatar list.
  defp clubs_from_libraries(libraries) do
    libraries
    |> Enum.map(fn lib ->
      lib
      |> String.split(" · ")
      |> List.first()
    end)
    |> Enum.uniq()
    |> Enum.map(fn name -> %{id: "club-" <> name, name: name} end)
  end

  # ---------------------------------------------------------------------------
  # Mock data — grouped
  # ---------------------------------------------------------------------------

  defp content_groups do
    rows = media_rows()

    expanse_media =
      rows
      |> Enum.filter(&(&1.content_title == "The Expanse"))

    dune_media =
      rows |> Enum.filter(&(&1.content_title == "Dune"))

    blade_media =
      rows
      |> Enum.filter(&(&1.content_title == "Blade Runner 2049"))
      |> Kernel.++([
        media_record(%{
          id: "m8-1080p",
          media_type: :video,
          content_type: :movie,
          match_status: :matched,
          path: "/mnt/media/movies/Blade Runner 2049.2017.1080p.mkv",
          content_title: "Blade Runner 2049",
          content_sub: "2017",
          libraries: ["Movie Night · Sci-Fi"],
          import_config: "filesystem-movies",
          size: "11.9 GB",
          container: "mkv",
          video_codec: "h264",
          framerate: "24 fps",
          resolution: :hd_1080p,
          hdr: false,
          audio_languages: ["en", "fr"],
          subtitle_languages: ["en", "fr"],
          audio_tracks: [
            %{language: "en", codec: "DTS", channels: "5.1"},
            %{language: "fr", codec: "AC3", channels: "5.1"}
          ],
          subtitle_tracks: [
            %{language: "en", default: true, forced: false},
            %{language: "fr", default: false, forced: false}
          ],
          imported_at: "2026-05-17 11:03"
        })
      ])

    foundation_media =
      rows |> Enum.filter(&(&1.content_title == "Foundation"))

    arrival_media =
      rows |> Enum.filter(&(&1.content_title == "Arrival"))

    [
      %{
        content_id: "c-the-expanse",
        content_type: :tv_show,
        title: "The Expanse",
        sub: "Sci-Fi · 2015",
        libraries: ["Movie Night · Sci-Fi"],
        missing_count: 21,
        failed_count: 0,
        media: expanse_media
      },
      %{
        content_id: "c-dune",
        content_type: :movie,
        title: "Dune",
        sub: "2021 · Sci-Fi",
        libraries: ["Movie Night · Sci-Fi", "Anders · Watchlist", "Family Room · Saturday"],
        missing_count: 0,
        failed_count: 0,
        media: dune_media
      },
      %{
        content_id: "c-blade-runner-2049",
        content_type: :movie,
        title: "Blade Runner 2049",
        sub: "2017 · Sci-Fi",
        libraries: ["Movie Night · Sci-Fi"],
        missing_count: 0,
        failed_count: 0,
        media: blade_media
      },
      %{
        content_id: "c-arrival",
        content_type: :movie,
        title: "Arrival",
        sub: "2016 · Sci-Fi",
        libraries: ["Movie Night · Sci-Fi", "Anders · Watchlist"],
        missing_count: 0,
        failed_count: 0,
        media: arrival_media
      },
      %{
        content_id: "c-foundation",
        content_type: :book,
        title: "Foundation",
        sub: "Isaac Asimov · 1951",
        libraries: ["Quiet Hours · Sci-Fi"],
        missing_count: 0,
        failed_count: 0,
        media: foundation_media
      }
    ]
  end

  defp unmatched_block do
    rows = media_rows()

    %{
      media:
        rows
        |> Enum.filter(&(&1.match_status != :matched))
    }
  end
end
