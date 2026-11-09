defmodule WatchClubWeb.Components.Navigation.AccountMenu do
  @moduledoc """
  The user's account links: User Preferences, the administration pages for Instance
  Administrators, and Sign out.

  `account_menu/1` shows them in a drop-down, at the bottom of the sidebar. `account_page/1` shows
  them on a full page for phones, a `<dialog>` that a button opens with
  `commandfor={id} command="show-modal"`, after the sections that have no phone tab.
  """
  use WatchClubWeb, :component

  attr :id, :string, required: true
  attr :user, User, required: true

  def account_menu(assigns) do
    ~H"""
    <.dropdown_menu id={@id} class="w-full">
      <:trigger>
        <button
          id={"#{@id}-button"}
          type="button"
          class="flex w-full items-center gap-related rounded-control p-related text-left transition-colors hover:bg-surface-hover aria-expanded:bg-surface-hover"
        >
          <.avatar id={@user.id} name={@user.username} size="md" aria-hidden="true" />
          <.user_name user={@user} />
          <Lucideicons.chevrons_up_down class="size-icon-sm shrink-0 text-text-subtle" />
        </button>
      </:trigger>

      <%!-- Repeats the trigger, so screen readers skip it --%>
      <div class="flex w-56 items-center gap-related p-related" aria-hidden="true">
        <.avatar id={@user.id} name={@user.username} size="md" />
        <.user_name user={@user} />
      </div>
      <.dropdown_menu_separator />
      <.dropdown_menu_item
        :for={link <- account_links()}
        id={"#{@id}-#{link.id}"}
        navigate={link.navigate}
      >
        <.lucide_icon name={link.icon} />{link.label}
      </.dropdown_menu_item>
      <div :if={@user.administrator?} role="group" aria-labelledby={"#{@id}-administration-title"}>
        <.dropdown_menu_separator />
        <p id={"#{@id}-administration-title"} class="px-related pt-related pb-tight text-xs">
          <.text_label text={dgettext("nav", "Administration")} />
        </p>
        <.dropdown_menu_item
          :for={link <- administration_links()}
          id={"#{@id}-#{link.id}"}
          navigate={link.navigate}
        >
          <.lucide_icon name={link.icon} />{link.label}
        </.dropdown_menu_item>
      </div>
      <.dropdown_menu_separator />
      <.dropdown_menu_item id={"#{@id}-sign-out"} href={~p"/sign-out"} method="delete">
        <Lucideicons.log_out />{dgettext("nav", "Sign out")}
      </.dropdown_menu_item>
    </.dropdown_menu>
    """
  end

  attr :id, :string, required: true
  attr :user, User, required: true

  attr :sections, :list,
    required: true,
    doc: "the sections without a phone tab, with their badges"

  def account_page(assigns) do
    ~H"""
    <dialog
      id={@id}
      aria-label={dgettext("nav", "Account")}
      phx-mounted={JS.ignore_attributes("open")}
      class="m-0 hidden h-dvh max-h-none w-full max-w-none flex-col border-0 bg-canvas p-0 text-text transition-[opacity,translate] duration-200 open:flex starting:open:translate-y-4 starting:open:opacity-0 md:hidden"
    >
      <div class="flex h-(--wc-app-bar-height) shrink-0 items-center border-b border-border-subtle pr-related pl-tight">
        <.button
          id={"#{@id}-close"}
          variant="ghost"
          size="icon"
          class="rounded-full! pointer-coarse:size-touch-target!"
          aria-label={dgettext("nav", "Close")}
          commandfor={@id}
          command="close"
          autofocus
        >
          <Lucideicons.x />
        </.button>
      </div>

      <div class="flex flex-1 flex-col gap-cluster overflow-y-auto px-page py-cluster">
        <div class="flex items-center gap-related px-related">
          <.avatar id={@user.id} name={@user.username} size="md" aria-hidden="true" />
          <.user_name user={@user} />
        </div>

        <.account_page_links id={"#{@id}-account"} links={@sections ++ account_links()} />

        <div :if={@user.administrator?} class="flex flex-col gap-related">
          <h2 id={"#{@id}-administration-title"} class="px-related text-xs">
            <.text_label text={dgettext("nav", "Administration")} />
          </h2>
          <.account_page_links
            id={"#{@id}-administration"}
            links={administration_links()}
            aria-labelledby={"#{@id}-administration-title"}
          />
        </div>

        <ul class="flex list-none flex-col rounded-card border border-border-subtle bg-surface p-0">
          <li>
            <.link
              id={"#{@id}-sign-out"}
              href={~p"/sign-out"}
              method="delete"
              class="flex min-h-touch-target items-center gap-group rounded-card px-group py-related font-semibold text-danger transition-colors hover:bg-surface-hover focus-visible:-outline-offset-2"
            >
              <Lucideicons.log_out class="size-icon" />{dgettext("nav", "Sign out")}
            </.link>
          </li>
        </ul>
      </div>
    </dialog>
    """
  end

  attr :user, User, required: true

  defp user_name(assigns) do
    ~H"""
    <span class="flex min-w-0 flex-1 flex-col">
      <span class="truncate text-sm font-semibold">{@user.username}</span>
      <span :if={@user.administrator?} class="truncate text-xs text-text-muted">
        {dgettext("nav", "Instance administrator")}
      </span>
    </span>
    """
  end

  attr :id, :string, required: true
  attr :links, :list, required: true
  attr :rest, :global

  defp account_page_links(assigns) do
    ~H"""
    <ul
      class="flex list-none flex-col divide-y divide-border-subtle rounded-card border border-border-subtle bg-surface p-0"
      {@rest}
    >
      <li :for={link <- @links}>
        <.link
          id={"#{@id}-#{link.id}"}
          navigate={link.navigate}
          class="flex min-h-touch-target items-center gap-group px-group py-related font-semibold transition-colors hover:bg-surface-hover focus-visible:-outline-offset-2"
        >
          <.lucide_icon name={link.icon} class="size-icon text-text-muted" />
          <span class="flex-1">{link.label}</span>
          <.unread_badge :if={link[:badge]} count={link.badge} label={link.badge_label} />
          <Lucideicons.chevron_right class="size-icon text-text-subtle" />
        </.link>
      </li>
    </ul>
    """
  end

  defp account_links do
    [
      %{
        id: "settings",
        label: dgettext("nav", "Settings"),
        navigate: ~p"/settings",
        icon: "settings"
      }
    ]
  end

  defp administration_links do
    [
      %{
        id: "instance-settings",
        label: dgettext("nav", "Instance settings"),
        navigate: ~p"/admin/settings",
        icon: "settings-2"
      },
      %{id: "users", label: dgettext("nav", "Users"), navigate: ~p"/admin/users", icon: "users"},
      %{
        id: "media-browser",
        label: dgettext("nav", "Media browser"),
        navigate: ~p"/admin/media",
        icon: "film"
      },
      %{
        id: "media-sources",
        label: dgettext("nav", "Media Sources"),
        navigate: ~p"/admin/media/sources",
        icon: "folder-input"
      },
      %{
        id: "problem-reports",
        label: dgettext("nav", "Problem reports"),
        navigate: ~p"/admin/problem-reports",
        icon: "flag"
      }
    ]
  end
end
