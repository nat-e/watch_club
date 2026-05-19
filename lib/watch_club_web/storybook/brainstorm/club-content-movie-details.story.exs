defmodule WatchClubWeb.Storybook.Brainstorm.ClubContentMovieDetails do
  @moduledoc """
  Temporary brainstorm mockups for adding club-scoped Library information to the Movie detail page.

  Safe to delete after the design decision is accepted or rejected.
  """
  use PhoenixStorybook.Story, :page
  use Phoenix.Component

  import WatchClubWeb.Components.UI.Avatar
  import WatchClubWeb.Components.UI.Badge
  import WatchClubWeb.Components.UI.Button
  import WatchClubWeb.Components.UI.Layout

  def doc do
    "Temporary brainstorm mockups comparing ways to show Library presence, Library Item activity, and Library Item comments on an unscoped Movie detail page."
  end

  def navigation do
    [
      {:snapshot_cards, "A: Library cards", {:fa, "layer-group"}},
      {:context_switcher, "B: Context switcher", {:fa, "sliders"}},
      {:activity_feed, "C: Activity feed", {:fa, "timeline"}},
      {:decision_matrix, "Compare", {:fa, "scale-balanced"}}
    ]
  end

  def render(%{tab: :context_switcher} = assigns) do
    assigns = assign(assigns, clubs: clubs(), selected: selected_library())

    ~H"""
    <.page_frame
      eyebrow="Alternative B"
      title="Choose one Library Item context before reading comments"
    >
      <:description>
        This keeps the Movie detail page unscoped, but asks the Member to pick which visible Library
        Item they are discussing before showing activity and comments.
      </:description>

      <.stack space="cluster">
        <.card padding="cluster" class="grid gap-cluster">
          <div class="flex flex-col gap-group xl:flex-row xl:items-center xl:justify-between">
            <div class="grid gap-tight">
              <div class="flex items-center gap-related text-accent">
                <Lucideicons.panel_right class="size-icon" />
                <h2 class="text-xl font-semibold tracking-tight">Library Item context</h2>
              </div>
              <p class="max-w-readable text-sm leading-6 text-text-muted">
                Comments are never global to the Movie. The selected chip controls which Library
                Item thread and watched list appears below.
              </p>
            </div>

            <.button id="context-switcher-add-button" variant="accent">
              <:icon><Lucideicons.list_plus /></:icon>
              Add to another Library
            </.button>
          </div>

          <div class="flex gap-related overflow-x-auto pb-tight">
            <button
              type="button"
              class="min-h-touch-target shrink-0 rounded-control border border-border bg-surface-raised px-group text-left text-sm text-text-muted"
            >
              <span class="block font-semibold text-text">All visible clubs</span>
              <span>Summary only</span>
            </button>
            <button
              type="button"
              class="min-h-touch-target shrink-0 rounded-control border border-accent-border bg-accent-bg px-group text-left text-sm text-accent"
            >
              <span class="block font-semibold text-text">Midnight Movies</span>
              <span>Main Watchlist · selected</span>
            </button>
            <button
              type="button"
              class="min-h-touch-target shrink-0 rounded-control border border-border bg-surface-raised px-group text-left text-sm text-text-muted"
            >
              <span class="block font-semibold text-text">Sunday Cinema</span>
              <span>May picks</span>
            </button>
          </div>
        </.card>

        <div class="grid gap-cluster xl:grid-cols-[minmax(0,1fr)_24rem]">
          <.selected_thread_panel selected={@selected} mode="focused" />
          <.add_elsewhere_panel clubs={@clubs} compact />
        </div>
      </.stack>
    </.page_frame>
    """
  end

  def render(%{tab: :activity_feed} = assigns) do
    assigns = assign(assigns, clubs: clubs(), events: feed_events())

    ~H"""
    <.page_frame
      eyebrow="Alternative C"
      title="Lead with one cross-club activity feed"
    >
      <:description>
        This aggregates visible Library Item activity across clubs and libraries. It is lively, but
        every event must carry club and Library context so comments do not feel global.
      </:description>

      <div class="grid gap-cluster xl:grid-cols-[minmax(0,1fr)_23rem]">
        <.card padding="cluster" class="grid gap-cluster">
          <div class="flex flex-col gap-related sm:flex-row sm:items-center sm:justify-between">
            <div class="grid gap-tight">
              <div class="flex items-center gap-related text-accent">
                <Lucideicons.activity class="size-icon" />
                <h2 class="text-xl font-semibold tracking-tight">Club activity for this Movie</h2>
              </div>
              <p class="text-sm leading-6 text-text-muted">
                Adds, watched marks, and latest comments from Library Items you can see.
              </p>
            </div>
            <.button id="activity-feed-comment-button" variant="secondary">
              <:icon><Lucideicons.message_circle_plus /></:icon>
              Comment…
            </.button>
          </div>

          <ol class="grid gap-group">
            <.feed_event :for={event <- @events} event={event} />
          </ol>
        </.card>

        <.card padding="cluster" class="grid content-start gap-cluster">
          <div class="grid gap-tight">
            <div class="flex items-center gap-related text-accent">
              <Lucideicons.library class="size-icon" />
              <h2 class="text-xl font-semibold tracking-tight">Libraries</h2>
            </div>
            <p class="text-sm leading-6 text-text-muted">
              Compact status stays available while the feed takes the main column.
            </p>
          </div>

          <div class="grid gap-related">
            <.compact_library_status :for={club <- @clubs} club={club} />
          </div>
        </.card>
      </div>
    </.page_frame>
    """
  end

  def render(%{tab: :decision_matrix} = assigns) do
    ~H"""
    <.page_frame
      eyebrow="Decision aid"
      title="Three viable shapes; one keeps the domain clearest"
      recommended
    >
      <:description>
        The main decision is how strongly the Movie page should surface the Library Item boundary.
        That boundary matters because comments are scoped to a Library Item, not to the Movie.
      </:description>

      <div class="grid gap-cluster lg:grid-cols-3">
        <.comparison_card
          option="A"
          title="Library cards + selected thread"
          verdict="Recommended"
          tone="success"
        >
          <:best_for>Scanning Library presence and then discussing one Library Item.</:best_for>
          <:tradeoff>More vertical content under the hero.</:tradeoff>
          <:why>
            Best match for the domain: Library presence is explicit, missing Libraries can be added
            quickly, and comments never appear detached from their Library Item.
          </:why>
        </.comparison_card>

        <.comparison_card
          option="B"
          title="Context switcher"
          verdict="Good when comments dominate"
          tone="accent"
        >
          <:best_for>A cleaner page when Members usually care about one club at a time.</:best_for>
          <:tradeoff>Library presence is partly hidden behind a chooser.</:tradeoff>
          <:why>
            The selected context is very clear, but Members may miss which Libraries do not yet have
            the Movie unless the add flow remains prominent.
          </:why>
        </.comparison_card>

        <.comparison_card
          option="C"
          title="Cross-club activity feed"
          verdict="Use cautiously"
          tone="muted"
        >
          <:best_for>Social proof and recent activity across many clubs.</:best_for>
          <:tradeoff>Highest risk of making Library Item comments feel global.</:tradeoff>
          <:why>
            It is lively, but the page has to repeat club and Library labels on every event to avoid
            mixing distinct discussion threads.
          </:why>
        </.comparison_card>
      </div>
    </.page_frame>
    """
  end

  def render(assigns) do
    assigns = assign(assigns, clubs: clubs(), selected: selected_library())

    ~H"""
    <.page_frame
      eyebrow="Alternative A"
      title="Show Library presence first, then one selected Library Item thread"
      recommended
    >
      <:description>
        This keeps the Movie detail page unscoped while making each club and Library explicit. A
        Member can see where the Movie is already a Library Item, add it elsewhere, then open the
        activity and comments for one Library Item.
      </:description>

      <div class="grid gap-cluster xl:grid-cols-[minmax(0,1fr)_25rem]">
        <.library_presence_panel clubs={@clubs} />
        <.selected_thread_panel selected={@selected} mode="side" />
      </div>
    </.page_frame>
    """
  end

  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  attr :recommended, :boolean, default: false
  slot :description, required: true
  slot :inner_block, required: true

  defp page_frame(assigns) do
    ~H"""
    <div class="theme-wc dark -m-8 min-h-screen bg-canvas p-page py-page-y text-text">
      <div class="mx-auto grid max-w-[100rem] gap-section">
        <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card xl:grid-cols-[14rem_minmax(0,1fr)] xl:items-center">
          <.poster_art />

          <div class="grid gap-cluster">
            <div class="grid gap-related">
              <div class="flex flex-wrap items-center gap-related">
                <.badge variant="accent" size="sm">Brainstorm / temporary</.badge>
                <.badge :if={@recommended} variant="success" size="sm">Recommended direction</.badge>
                <span class="text-sm font-medium text-text-subtle">Movie detail page</span>
              </div>
              <p class="text-sm font-semibold tracking-[0.28em] text-accent uppercase">
                {@eyebrow}
              </p>
              <h1 class="max-w-4xl text-4xl leading-none font-semibold tracking-tight text-text xl:text-5xl">
                {@title}
              </h1>
              <p class="max-w-readable text-sm leading-6 text-text-muted">
                {render_slot(@description)}
              </p>
            </div>

            <div class="grid gap-tight">
              <p class="text-2xl font-semibold tracking-tight">Arrival</p>
              <div class="flex flex-wrap items-center gap-related text-sm text-text-muted">
                <span>2016</span>
                <span aria-hidden="true">•</span>
                <span>1h 56m</span>
                <span aria-hidden="true">•</span>
                <span>Science fiction</span>
              </div>
            </div>

            <.cluster>
              <.button id="brainstorm-add-to-library-button" size="lg" variant="accent">
                <:icon><Lucideicons.list_plus /></:icon>
                In 2 clubs
              </.button>
              <.button id="brainstorm-trailer-button" size="lg" variant="secondary">
                <:icon><Lucideicons.play_circle /></:icon>
                Watch Trailer
              </.button>
            </.cluster>
          </div>
        </section>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp poster_art(assigns) do
    ~H"""
    <div class="mx-auto grid aspect-[2/3] w-44 place-items-end overflow-hidden rounded-card border border-border-subtle bg-[radial-gradient(circle_at_35%_25%,var(--wc-color-accent-bg),transparent_45%),linear-gradient(145deg,var(--wc-color-surface-raised),var(--wc-color-surface-inset))] p-group shadow-overlay xl:w-full">
      <div class="grid gap-tight text-left">
        <p class="text-4xl font-black leading-none tracking-tight text-text">ARR</p>
        <p class="text-xs font-semibold tracking-[0.28em] text-text-muted uppercase">mock poster</p>
      </div>
    </div>
    """
  end

  attr :clubs, :list, required: true

  defp library_presence_panel(assigns) do
    ~H"""
    <.card padding="cluster" class="grid gap-cluster">
      <div class="flex flex-col gap-related sm:flex-row sm:items-start sm:justify-between">
        <div class="grid gap-tight">
          <div class="flex items-center gap-related text-accent">
            <Lucideicons.library class="size-icon" />
            <h2 class="text-xl font-semibold tracking-tight">Your Movie Libraries</h2>
          </div>
          <p class="max-w-readable text-sm leading-6 text-text-muted">
            Shows every Movie Library in clubs where you are a Member, including Libraries where
            this Movie is not yet present.
          </p>
        </div>
        <.badge variant="secondary">Movie Libraries only</.badge>
      </div>

      <div class="grid gap-cluster">
        <.club_library_group :for={club <- @clubs} club={club} />
      </div>
    </.card>
    """
  end

  attr :club, :map, required: true

  defp club_library_group(assigns) do
    ~H"""
    <section class="grid gap-related">
      <div class="flex items-center justify-between gap-related">
        <div class="flex min-w-0 items-center gap-related">
          <.avatar id={@club.id} name={@club.name} />
          <div class="min-w-0">
            <h3 class="truncate font-semibold text-text">{@club.name}</h3>
            <p class="text-sm text-text-muted">{@club.summary}</p>
          </div>
        </div>
        <.badge variant={if @club.present_count > 0, do: "success", else: "muted"}>
          {@club.present_count}/{length(@club.libraries)} in Library
        </.badge>
      </div>

      <div class="grid gap-related">
        <.library_status_row :for={library <- @club.libraries} club={@club} library={library} />
      </div>
    </section>
    """
  end

  attr :club, :map, required: true
  attr :library, :map, required: true

  defp library_status_row(assigns) do
    ~H"""
    <article class="grid gap-group rounded-control border border-border-subtle bg-surface-inset p-group md:grid-cols-[minmax(0,1fr)_auto] md:items-center">
      <div class="grid gap-related">
        <div class="flex flex-wrap items-center gap-related">
          <.badge variant={if @library.status == :in_library, do: "success", else: "muted"}>
            <:icon :if={@library.status == :in_library}><Lucideicons.circle_check /></:icon>
            {if @library.status == :in_library, do: "In Library", else: "Not in Library"}
          </.badge>
          <h4 class="font-semibold text-text">{@library.name}</h4>
        </div>

        <div
          :if={@library.status == :in_library}
          class="flex flex-wrap items-center gap-related text-sm text-text-muted"
        >
          <span class="inline-flex items-center gap-tight">
            <.avatar id={@library.added_by_id} name={@library.added_by} size="xs" /> Added by
            <strong class="font-semibold text-text">{@library.added_by}</strong>
          </span>
          <span aria-hidden="true">•</span>
          <span>{@library.added_at}</span>
        </div>

        <div
          :if={@library.status == :in_library}
          class="flex flex-wrap items-center gap-related text-sm text-text-muted"
        >
          <span class="inline-flex items-center gap-tight">
            <Lucideicons.eye class="size-icon-sm text-success" />
            {length(@library.watchers)} watched
          </span>
          <span class="inline-flex items-center gap-tight">
            <Lucideicons.message_circle class="size-icon-sm text-accent" />
            {@library.comments} comments
          </span>
          <.avatar_group :if={@library.watchers != []} avatars={@library.watchers} avatar_size="xs" />
        </div>

        <p :if={@library.status == :not_in_library} class="text-sm leading-6 text-text-muted">
          Add to Library would create a new Library Item for {@club.name} / {@library.name}.
        </p>
      </div>

      <div class="flex justify-end">
        <.button
          :if={@library.status == :in_library}
          id={"open-thread-#{@library.id}"}
          variant="secondary"
          size="sm"
        >
          Open thread
          <:icon position="end"><Lucideicons.chevron_right /></:icon>
        </.button>
        <.button
          :if={@library.status == :not_in_library}
          id={"add-library-#{@library.id}"}
          variant="accent"
          size="sm"
        >
          <:icon><Lucideicons.list_plus /></:icon>
          Add to Library
        </.button>
      </div>
    </article>
    """
  end

  attr :selected, :map, required: true
  attr :mode, :string, default: "side"

  defp selected_thread_panel(assigns) do
    ~H"""
    <.card padding="cluster" class="grid content-start gap-cluster">
      <div class="grid gap-related">
        <div class="flex items-start justify-between gap-related">
          <div class="grid gap-tight">
            <div class="flex items-center gap-related text-accent">
              <Lucideicons.messages_square class="size-icon" />
              <h2 class="text-xl font-semibold tracking-tight">
                {if @mode == "focused", do: "Selected Library Item", else: "Activity + comments"}
              </h2>
            </div>
            <p class="text-sm leading-6 text-text-muted">
              {@selected.club} / {@selected.library}
            </p>
          </div>
          <.badge variant="success">In Library</.badge>
        </div>

        <div class="grid grid-cols-2 gap-related">
          <.metric label="Watched" value="3" icon={:eye} />
          <.metric label="Comments" value="8" icon={:message_circle} />
        </div>
      </div>

      <section class="grid gap-group">
        <h3 class="text-sm font-semibold tracking-[0.18em] text-text-subtle uppercase">Activity</h3>
        <ol class="grid gap-related">
          <.timeline_item actor="Ada Lovelace" actor_id="ada" icon={:list_plus} time="2 days ago">
            Added this Movie to Main Watchlist.
          </.timeline_item>
          <.timeline_item actor="Grace Hopper" actor_id="grace" icon={:eye} time="yesterday">
            Marked it watched.
          </.timeline_item>
          <.timeline_item actor="You" actor_id="you" icon={:eye} time="today">
            Marked it watched.
          </.timeline_item>
        </ol>
      </section>

      <section class="grid gap-group">
        <h3 class="text-sm font-semibold tracking-[0.18em] text-text-subtle uppercase">Comments</h3>
        <div class="grid gap-related">
          <.comment author="Ada Lovelace" author_id="ada" time="2 days ago">
            Adding this for Saturday. The sound design deserves a good setup.
          </.comment>
          <.comment author="Grace Hopper" author_id="grace" time="yesterday">
            Watched it again — still in for a group discussion.
          </.comment>
        </div>
        <div class="grid gap-related rounded-control border border-border bg-surface-inset p-related">
          <p class="text-sm text-text-subtle">Write a comment in Midnight Movies / Main Watchlist…</p>
          <div class="flex justify-end">
            <.button id="comment-submit-mock" variant="primary" size="sm">Comment</.button>
          </div>
        </div>
      </section>
    </.card>
    """
  end

  attr :clubs, :list, required: true
  attr :compact, :boolean, default: false

  defp add_elsewhere_panel(assigns) do
    ~H"""
    <.card padding="cluster" class="grid content-start gap-cluster">
      <div class="grid gap-tight">
        <div class="flex items-center gap-related text-accent">
          <Lucideicons.list_plus class="size-icon" />
          <h2 class="text-xl font-semibold tracking-tight">Add elsewhere</h2>
        </div>
        <p class="text-sm leading-6 text-text-muted">
          Missing Movie Libraries remain one tap away even after a context is selected.
        </p>
      </div>

      <div class="grid gap-related">
        <div :for={club <- @clubs} class="grid gap-tight">
          <p class="text-sm font-semibold text-text-muted">{club.name}</p>
          <button
            :for={library <- Enum.filter(club.libraries, &(&1.status == :not_in_library))}
            type="button"
            class="flex min-h-touch-target items-center justify-between rounded-control border border-border bg-surface-raised px-group text-left text-sm hover:bg-surface-hover"
          >
            <span class="font-semibold text-text">{library.name}</span>
            <span class="text-accent">Add</span>
          </button>
        </div>
      </div>
    </.card>
    """
  end

  attr :club, :map, required: true

  defp compact_library_status(assigns) do
    ~H"""
    <section class="grid gap-tight rounded-control border border-border-subtle bg-surface-inset p-related">
      <div class="flex items-center gap-related">
        <.avatar id={@club.id} name={@club.name} size="sm" />
        <h3 class="font-semibold text-text">{@club.name}</h3>
      </div>
      <div class="grid gap-tight">
        <div
          :for={library <- @club.libraries}
          class="flex items-center justify-between gap-related text-sm"
        >
          <span class="truncate text-text-muted">{library.name}</span>
          <.badge variant={if library.status == :in_library, do: "success", else: "muted"} size="sm">
            {if library.status == :in_library, do: "In", else: "Add"}
          </.badge>
        </div>
      </div>
    </section>
    """
  end

  attr :event, :map, required: true

  defp feed_event(assigns) do
    ~H"""
    <li class="grid gap-related rounded-control border border-border-subtle bg-surface-inset p-group">
      <div class="flex flex-wrap items-center gap-related text-sm text-text-muted">
        <.avatar id={@event.actor_id} name={@event.actor} size="sm" />
        <strong class="font-semibold text-text">{@event.actor}</strong>
        <span>{@event.action}</span>
        <span aria-hidden="true">•</span>
        <span>{@event.time}</span>
      </div>
      <div class="flex flex-wrap items-center gap-related">
        <.badge variant="secondary" size="sm">{@event.club}</.badge>
        <.badge variant="muted" size="sm">{@event.library}</.badge>
      </div>
      <p
        :if={@event.body}
        class="rounded-control border border-border bg-surface p-related text-sm leading-6 text-text-muted"
      >
        {@event.body}
      </p>
    </li>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :atom, required: true

  defp metric(assigns) do
    ~H"""
    <div class="rounded-control border border-border-subtle bg-surface-inset p-related">
      <div class="flex items-center gap-tight text-text-muted">
        <.dynamic_icon name={@icon} class="size-icon-sm" />
        <span class="text-xs font-semibold uppercase tracking-[0.14em]">{@label}</span>
      </div>
      <p class="mt-tight text-2xl font-semibold text-text">{@value}</p>
    </div>
    """
  end

  attr :actor, :string, required: true
  attr :actor_id, :string, required: true
  attr :icon, :atom, required: true
  attr :time, :string, required: true
  slot :inner_block, required: true

  defp timeline_item(assigns) do
    ~H"""
    <li class="flex gap-related text-sm leading-6">
      <span class="mt-1 grid size-7 shrink-0 place-items-center rounded-full border border-border bg-surface-raised text-accent">
        <.dynamic_icon name={@icon} class="size-icon-sm" />
      </span>
      <div class="min-w-0">
        <p class="text-text-muted">
          <span class="inline-flex items-center gap-tight font-semibold text-text">
            <.avatar id={@actor_id} name={@actor} size="xs" />
            {@actor}
          </span>
          {render_slot(@inner_block)}
        </p>
        <p class="text-xs text-text-subtle">{@time}</p>
      </div>
    </li>
    """
  end

  attr :author, :string, required: true
  attr :author_id, :string, required: true
  attr :time, :string, required: true
  slot :inner_block, required: true

  defp comment(assigns) do
    ~H"""
    <article class="grid gap-tight rounded-control border border-border bg-surface-inset p-related">
      <div class="flex items-center justify-between gap-related text-sm">
        <span class="inline-flex items-center gap-tight font-semibold text-text">
          <.avatar id={@author_id} name={@author} size="xs" />
          {@author}
        </span>
        <span class="text-xs text-text-subtle">{@time}</span>
      </div>
      <p class="text-sm leading-6 text-text-muted">{render_slot(@inner_block)}</p>
    </article>
    """
  end

  attr :option, :string, required: true
  attr :title, :string, required: true
  attr :verdict, :string, required: true
  attr :tone, :string, required: true
  slot :best_for, required: true
  slot :tradeoff, required: true
  slot :why, required: true

  defp comparison_card(assigns) do
    ~H"""
    <.card padding="cluster" class="grid content-start gap-cluster">
      <div class="grid gap-related">
        <div class="flex items-center justify-between gap-related">
          <span class="grid size-10 place-items-center rounded-control bg-primary text-sm font-bold text-on-primary">
            {@option}
          </span>
          <.badge variant={@tone}>{@verdict}</.badge>
        </div>
        <h2 class="text-2xl font-semibold tracking-tight text-text">{@title}</h2>
      </div>

      <div class="grid gap-group text-sm leading-6">
        <div>
          <p class="font-semibold text-text">Best for</p>
          <p class="text-text-muted">{render_slot(@best_for)}</p>
        </div>
        <div>
          <p class="font-semibold text-text">Trade-off</p>
          <p class="text-text-muted">{render_slot(@tradeoff)}</p>
        </div>
        <div class="rounded-control border border-border-subtle bg-surface-inset p-related">
          <p class="text-text-muted">{render_slot(@why)}</p>
        </div>
      </div>
    </.card>
    """
  end

  attr :name, :atom, required: true
  attr :class, :string, default: "size-icon"

  defp dynamic_icon(assigns) do
    ~H"""
    {apply(Lucideicons, @name, [%{class: @class, __changed__: %{}}])}
    """
  end

  defp selected_library do
    %{
      club: "Midnight Movies",
      library: "Main Watchlist"
    }
  end

  defp clubs do
    [
      %{
        id: "midnight-movies",
        name: "Midnight Movies",
        summary: "2 Movie Libraries",
        present_count: 1,
        libraries: [
          %{
            id: "mm-main-watchlist",
            name: "Main Watchlist",
            status: :in_library,
            added_by: "Ada Lovelace",
            added_by_id: "ada",
            added_at: "2 days ago",
            watchers: [
              %{id: "ada", name: "Ada Lovelace"},
              %{id: "grace", name: "Grace Hopper"},
              %{id: "you", name: "You"}
            ],
            comments: 8
          },
          %{
            id: "mm-rewatch-queue",
            name: "Rewatch Queue",
            status: :not_in_library,
            added_by: nil,
            added_by_id: nil,
            added_at: nil,
            watchers: [],
            comments: 0
          }
        ]
      },
      %{
        id: "sunday-cinema",
        name: "Sunday Cinema",
        summary: "2 Movie Libraries",
        present_count: 1,
        libraries: [
          %{
            id: "sc-may-picks",
            name: "May picks",
            status: :in_library,
            added_by: "You",
            added_by_id: "you",
            added_at: "last week",
            watchers: [
              %{id: "you", name: "You"},
              %{id: "katherine", name: "Katherine Johnson"}
            ],
            comments: 3
          },
          %{
            id: "sc-classics",
            name: "Classics",
            status: :not_in_library,
            added_by: nil,
            added_by_id: nil,
            added_at: nil,
            watchers: [],
            comments: 0
          }
        ]
      },
      %{
        id: "family-night",
        name: "Family Night",
        summary: "1 Movie Library",
        present_count: 0,
        libraries: [
          %{
            id: "fn-weekend",
            name: "Weekend queue",
            status: :not_in_library,
            added_by: nil,
            added_by_id: nil,
            added_at: nil,
            watchers: [],
            comments: 0
          }
        ]
      }
    ]
  end

  defp feed_events do
    [
      %{
        actor: "Grace Hopper",
        actor_id: "grace",
        action: "commented",
        time: "1 hour ago",
        club: "Midnight Movies",
        library: "Main Watchlist",
        body: "Watched it again — still in for a group discussion."
      },
      %{
        actor: "You",
        actor_id: "you",
        action: "marked it watched",
        time: "today",
        club: "Midnight Movies",
        library: "Main Watchlist",
        body: nil
      },
      %{
        actor: "Katherine Johnson",
        actor_id: "katherine",
        action: "marked it watched",
        time: "yesterday",
        club: "Sunday Cinema",
        library: "May picks",
        body: nil
      },
      %{
        actor: "Ada Lovelace",
        actor_id: "ada",
        action: "added it to a Library",
        time: "2 days ago",
        club: "Midnight Movies",
        library: "Main Watchlist",
        body: nil
      }
    ]
  end
end
