defmodule WatchClubWeb.Components.Navigation.Sidebar do
  @moduledoc """
  The navigation on desktop: the app's sections, then the account menu.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Navigation.AccountMenu

  alias WatchClubWeb.Components.Navigation.Sections

  attr :current_path, :string, required: true
  attr :current_user, User, required: true
  attr :instance_settings, InstanceSettings, required: true

  def sidebar(assigns) do
    ~H"""
    <aside
      id="sidebar"
      class="fixed inset-y-0 left-0 z-20 hidden w-(--wc-sidebar-width) flex-col bg-surface text-text md:flex"
    >
      <header class="flex h-row-lg shrink-0 items-center pr-related pl-group">
        <.link
          id="sidebar-instance-link"
          navigate={~p"/"}
          class="min-w-0 truncate rounded-control font-heading text-base font-semibold"
        >
          {@instance_settings.name}
        </.link>
      </header>

      <nav
        aria-label={dgettext("nav", "Main navigation")}
        class="flex flex-1 flex-col overflow-y-auto px-related pt-related pb-group"
      >
        <ul class="flex list-none flex-col gap-px p-0">
          <li :for={section <- Sections.sections(@current_user)}>
            <.section_link section={section} current={Sections.aria_current(section, @current_path)} />
          </li>
        </ul>
      </nav>

      <div class="shrink-0 border-t border-border-subtle p-related">
        <.account_menu id="sidebar-account-menu" user={@current_user} />
      </div>
    </aside>
    """
  end

  attr :section, :map, required: true
  attr :current, :string, required: true

  defp section_link(assigns) do
    ~H"""
    <.link
      id={"sidebar-#{@section.id}-link"}
      navigate={@section.navigate}
      aria-current={@current}
      class={[
        "flex min-h-touch-target items-center gap-related rounded-control px-related text-sm font-semibold transition-colors pointer-fine:min-h-9 [&_svg]:size-icon-sm [&_svg]:shrink-0",
        @current && "bg-surface-selected text-text [&_svg]:text-text-muted",
        !@current && "text-text-muted hover:bg-surface-hover hover:text-text [&_svg]:text-text-subtle"
      ]}
    >
      <.lucide_icon name={@section.icon} />
      <span class="min-w-0 flex-1 truncate">{@section.label}</span>
      <.unread_badge count={@section.badge} label={@section.badge_label} />
    </.link>
    """
  end
end
