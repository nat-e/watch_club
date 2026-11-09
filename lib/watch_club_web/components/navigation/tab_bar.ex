defmodule WatchClubWeb.Components.Navigation.TabBar do
  @moduledoc """
  The tabs at the bottom of the screen on phones: the app's sections, then You, which opens the
  account page with the sections that have no tab. You carries their badges.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Navigation.AccountMenu

  alias WatchClubWeb.Components.Navigation.Sections

  attr :current_path, :string, required: true
  attr :current_user, User, required: true
  attr :class, :any, default: nil

  def tab_bar(assigns) do
    {tab_sections, you_sections} =
      assigns.current_user |> Sections.sections() |> Enum.split_with(& &1.phone?)

    assigns = assign(assigns, tab_sections: tab_sections, you_sections: you_sections)

    ~H"""
    <nav
      id="tab-bar"
      aria-label={dgettext("nav", "Main navigation")}
      class={[
        "fixed inset-x-0 bottom-0 z-30 border-t border-border-subtle bg-surface md:hidden",
        @class
      ]}
    >
      <ul class="flex h-(--wc-tab-bar-height) list-none p-0">
        <li :for={section <- @tab_sections} class="flex min-w-0 flex-1">
          <.section_tab section={section} current={Sections.aria_current(section, @current_path)} />
        </li>
        <li class="flex min-w-0 flex-1">
          <button
            id="tab-you"
            type="button"
            aria-haspopup="dialog"
            aria-controls="account-page"
            commandfor="account-page"
            command="show-modal"
            class="relative flex min-w-0 flex-1 flex-col items-center justify-center gap-tight text-xs text-text-muted focus-visible:-outline-offset-2"
          >
            <span class="flex h-control-sm w-14 items-center justify-center">
              <.avatar
                id={@current_user.id}
                name={@current_user.username}
                size="md"
                aria-hidden="true"
              />
            </span>
            <span class="max-w-full truncate">{dgettext("nav", "You")}</span>
            <.unread_badge
              count={@you_sections |> Enum.map(& &1.badge) |> Enum.sum()}
              label={
                @you_sections |> Enum.filter(&(&1.badge > 0)) |> Enum.map_join(", ", & &1.badge_label)
              }
              class="absolute top-1 left-[calc(50%+0.75rem)]"
            />
          </button>
        </li>
      </ul>
    </nav>

    <.account_page id="account-page" user={@current_user} sections={@you_sections} />
    """
  end

  attr :section, :map, required: true
  attr :current, :string, required: true

  defp section_tab(assigns) do
    ~H"""
    <.link
      id={"tab-#{@section.id}"}
      navigate={@section.navigate}
      aria-current={@current}
      class="relative flex min-w-0 flex-1 flex-col items-center justify-center gap-tight text-xs focus-visible:-outline-offset-2"
    >
      <span class={[
        "flex h-control-sm w-14 items-center justify-center rounded-full transition-colors [&_svg]:size-icon",
        @current && "bg-surface-selected text-text",
        !@current && "text-text-muted"
      ]}>
        <.lucide_icon name={@section.icon} />
      </span>
      <span class={[
        "max-w-full truncate",
        @current && "font-semibold text-text",
        !@current && "text-text-muted"
      ]}>
        {@section.label}
      </span>
      <.unread_badge
        count={@section.badge}
        label={@section.badge_label}
        class="absolute top-1 left-[calc(50%+0.75rem)]"
      />
    </.link>
    """
  end
end
