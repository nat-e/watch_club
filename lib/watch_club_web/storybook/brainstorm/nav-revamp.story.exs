defmodule WatchClubWeb.Storybook.Brainstorm.NavRevamp do
  @moduledoc """
  Temporary brainstorm mockups for the navigation revamp.

  Goal of the revamp:
    - Remove the user menu + avatar from the top navbar (it becomes search-only).
    - Move user info, Settings, and Sign out to a bottom section in the sidebar.
    - Surface an Admin section (Instance settings, Media browser, Import media)
      to instance administrators only, sitting just above the user card.

  Safe to delete after the design decision is accepted or rejected.
  """
  use PhoenixStorybook.Story, :page
  use Phoenix.Component

  import WatchClubWeb.Components.UI.Avatar
  import WatchClubWeb.Components.UI.Badge
  import WatchClubWeb.Components.UI.Button
  import WatchClubWeb.Components.UI.LucideIcon

  def doc do
    "Brainstorm mockup for the navigation revamp: user menu moves from the navbar into a sidebar bottom section with Settings + Sign out as full nav items, and admins get an Admin section above it."
  end

  def navigation do
    [
      {:admin, "Admin view", {:fa, "shield"}},
      {:non_admin, "Non-admin · for reference", {:fa, "eye-slash"}}
    ]
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Admin view — expanded user card + admin section
  # ──────────────────────────────────────────────────────────────────────────

  def render(%{tab: :admin} = assigns) do
    ~H"""
    <.frame
      eyebrow="Admin view"
      title="User identity + Settings/Sign out as nav items, Admin section above"
    >
      <:description>
        Bottom block shows the user identity (avatar + username) with a ghost Sign out icon
        button on the same row, painted in destructive foreground only (no filled red at rest).
        Settings sits under it as a full-width sidebar item for readability. Above the user
        block, the Admin section is visible only to instance administrators: Instance settings,
        Media browser, Import media.
      </:description>

      <.layout_mock>
        <:sidebar>
          <.sidebar_main />
          <.sidebar_admin_section />
          <.user_card_expanded user={current_user()} />
        </:sidebar>
        <:navbar><.simplified_navbar /></:navbar>
        <:page><.placeholder_page /></:page>
      </.layout_mock>
    </.frame>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Non-admin reference — same layout, admin section hidden
  # ──────────────────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <.frame
      eyebrow="Non-admin"
      title="Same layout, admin section hidden"
    >
      <:description>
        Reference rendering for a regular member: no Admin section, just the bottom user card.
        Confirms the bottom region still reads well without the admin block above it.
      </:description>

      <.layout_mock>
        <:sidebar>
          <.sidebar_main />
          <.user_card_expanded user={current_user()} />
        </:sidebar>
        <:navbar><.simplified_navbar /></:navbar>
        <:page><.placeholder_page /></:page>
      </.layout_mock>
    </.frame>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Layout mock — sidebar (fixed) + main column (navbar + page)
  # ──────────────────────────────────────────────────────────────────────────

  slot :sidebar, required: true
  slot :navbar, required: true
  slot :page, required: true

  defp layout_mock(assigns) do
    ~H"""
    <div class="overflow-hidden rounded-card border border-border-subtle bg-canvas shadow-card">
      <div class="grid min-h-[640px] grid-cols-[16rem_1fr] bg-canvas text-text">
        <aside class="flex flex-col border-r border-border-subtle bg-surface">
          {render_slot(@sidebar)}
        </aside>
        <div class="flex flex-col">
          {render_slot(@navbar)}
          <div class="flex-1 bg-canvas">
            {render_slot(@page)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Sidebar pieces — header, main nav, admin section
  # ──────────────────────────────────────────────────────────────────────────

  defp sidebar_main(assigns) do
    ~H"""
    <header class="flex h-row-lg shrink-0 items-center px-cluster">
      <h2 class="font-heading text-xl font-semibold">watch.club</h2>
    </header>

    <nav class="flex flex-1 flex-col gap-group overflow-y-auto p-group">
      <ul class="flex list-none flex-col gap-tight p-0">
        <li><.fake_item icon="home" label="Home" active /></li>
        <li><.fake_item icon="bookmark" label="Watchlist" /></li>
      </ul>

      <h3 class="px-group pt-related text-xs font-semibold tracking-wide text-text-subtle uppercase">
        Clubs
      </h3>

      <ul class="flex list-none flex-col gap-tight p-0">
        <li><.fake_club_item id="club-1" name="Movie nights" /></li>
        <li><.fake_club_item id="club-2" name="Cinephiles Anonymous" /></li>
        <li>
          <.fake_item icon="plus" label="Create new club" muted />
        </li>
      </ul>
    </nav>
    """
  end

  defp sidebar_admin_section(assigns) do
    ~H"""
    <div class="flex flex-col gap-tight border-t border-border-subtle px-group py-group">
      <h3 class="px-group text-xs font-semibold tracking-wide text-text-subtle uppercase">
        Admin
      </h3>
      <ul class="flex list-none flex-col gap-tight p-0">
        <li><.fake_item icon="settings_2" label="Instance settings" /></li>
        <li><.fake_item icon="film" label="Media browser" /></li>
        <li><.fake_item icon="folder_input" label="Import media" /></li>
      </ul>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Sidebar nav items (visual-only stand-ins; mirror the real sidebar_item)
  # ──────────────────────────────────────────────────────────────────────────

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :muted, :boolean, default: false

  defp fake_item(assigns) do
    ~H"""
    <div class={[
      "flex min-h-touch-target items-center gap-related rounded-control border border-transparent px-group text-sm font-medium transition-colors",
      @active && "bg-surface-selected text-text",
      !@active && !@muted && "text-text hover:bg-surface-hover",
      @muted && "text-text-muted hover:bg-surface-hover hover:text-text"
    ]}>
      <.lucide_icon name={@icon} />
      <span class="min-w-0 flex-1 truncate">{@label}</span>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :name, :string, required: true

  defp fake_club_item(assigns) do
    ~H"""
    <div class="flex min-h-touch-target items-center overflow-hidden rounded-control border border-transparent text-text-muted hover:bg-surface-hover hover:text-text">
      <div class="flex min-h-touch-target min-w-0 flex-1 items-center gap-related px-group text-sm font-semibold text-inherit">
        <.avatar id={@id} name={@name} size="md" />
        <span class="min-w-0 flex-1 truncate">{@name}</span>
      </div>
      <span class="grid size-control-sm shrink-0 place-items-center pr-tight text-inherit">
        <.lucide_icon name="ellipsis_vertical" class="size-icon-sm" />
      </span>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # User card — expanded with inline Settings + Sign out (destructive)
  # ──────────────────────────────────────────────────────────────────────────

  attr :user, :map, required: true

  defp user_card_expanded(assigns) do
    ~H"""
    <div class="flex flex-col gap-tight border-t border-border-subtle p-group">
      <div class="flex min-h-touch-target items-center gap-related px-group text-sm font-semibold text-text">
        <.avatar id={@user.id} name={@user.username} size="md" />
        <span class="min-w-0 flex-1 truncate">{@user.username}</span>
        <.button
          id="brainstorm-user-expanded-signout"
          variant="ghost"
          size="icon-sm"
          class="border-danger-border text-danger hover:bg-danger-bg hover:text-danger"
          aria-label="Sign out"
        >
          <.lucide_icon name="log_out" />
        </.button>
      </div>
      <ul class="flex list-none flex-col gap-tight p-0">
        <li><.fake_item icon="settings" label="Settings" /></li>
      </ul>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Simplified navbar (no avatar / no user menu)
  # ──────────────────────────────────────────────────────────────────────────

  defp simplified_navbar(assigns) do
    ~H"""
    <header class="z-10 flex h-row-lg items-center gap-related border-b border-border-subtle px-cluster">
      <div class="flex w-full max-w-2xl items-center gap-related rounded-control border border-border bg-surface-raised px-group py-related text-sm text-text-muted">
        <.lucide_icon name="search" class="size-icon-sm" />
        <span class="flex-1">Search movies, shows, clubs…</span>
        <span class="rounded-control border border-border-subtle bg-surface px-tight py-px text-[10px] font-medium tracking-wide text-text-subtle">
          /
        </span>
      </div>
    </header>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Page placeholder — context only, not part of the design under review
  # ──────────────────────────────────────────────────────────────────────────

  defp placeholder_page(assigns) do
    ~H"""
    <div class="grid h-full gap-cluster p-cluster">
      <div class="h-8 w-48 rounded-control bg-surface-raised"></div>
      <div class="grid grid-cols-2 gap-cluster sm:grid-cols-3 lg:grid-cols-4">
        <div :for={_ <- 1..8} class="aspect-[2/3] rounded-card bg-surface-raised"></div>
      </div>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Frame
  # ──────────────────────────────────────────────────────────────────────────

  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  slot :description, required: true
  slot :inner_block, required: true

  defp frame(assigns) do
    ~H"""
    <div class="theme-wc dark -m-8 min-h-screen bg-canvas p-page py-page-y text-text">
      <div class="mx-auto grid max-w-[80rem] gap-section">
        <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
          <div class="grid gap-related">
            <div class="flex flex-wrap items-center gap-related">
              <.badge variant="accent" size="sm">Brainstorm · temporary</.badge>
              <span class="text-sm font-medium text-text-subtle">Navigation revamp</span>
            </div>
            <p class="text-sm font-semibold tracking-[0.28em] text-accent uppercase">{@eyebrow}</p>
            <h1 class="max-w-4xl text-3xl leading-tight font-semibold tracking-tight text-text">
              {@title}
            </h1>
            <p class="max-w-readable text-sm leading-6 text-text-muted">{render_slot(@description)}</p>
          </div>
        </section>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Mock data
  # ──────────────────────────────────────────────────────────────────────────

  defp current_user do
    %{
      id: "01HZX-user",
      username: "nathan"
    }
  end
end
