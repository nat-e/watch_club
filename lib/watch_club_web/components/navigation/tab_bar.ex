defmodule WatchClubWeb.Components.Navigation.TabBar do
  @moduledoc """
  The tabs at the bottom of the screen on phones: Home, Clubs, Search, Lists and My Requests.
  """
  use WatchClubWeb, :component

  attr :current_path, :string, required: true

  def tab_bar(assigns) do
    ~H"""
    <nav
      aria-label={dgettext("nav", "Main navigation")}
      class="fixed inset-x-0 bottom-0 z-30 border-t border-border-subtle bg-surface md:hidden"
    >
      <ul class="flex h-(--wc-tab-bar-height) list-none p-0">
        <.tab
          id="tab-home"
          navigate={~p"/"}
          label={dgettext("nav", "Home")}
          current_path={@current_path}
        >
          <Lucideicons.house />
        </.tab>
        <.tab
          id="tab-clubs"
          navigate={~p"/clubs"}
          label={dgettext("nav", "Clubs")}
          current_path={@current_path}
        >
          <Lucideicons.users />
        </.tab>
        <.tab
          id="tab-search"
          navigate={~p"/search"}
          label={dgettext("nav", "Search")}
          current_path={@current_path}
        >
          <Lucideicons.search />
        </.tab>
        <.tab
          id="tab-lists"
          navigate={~p"/lists"}
          label={dgettext("nav", "Lists")}
          current_path={@current_path}
        >
          <Lucideicons.list_video />
        </.tab>
        <.tab
          id="tab-my-requests"
          navigate={~p"/my-requests"}
          label={dgettext("nav", "Requests")}
          current_path={@current_path}
        >
          <Lucideicons.inbox />
        </.tab>
      </ul>
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :navigate, :string, required: true
  attr :label, :string, required: true
  attr :current_path, :string, required: true
  slot :inner_block, required: true, doc: "the icon"

  # A tab is selected on its page, and on the pages under it, such as a club's libraries under
  # Clubs.
  defp tab(assigns) do
    assigns =
      assign(assigns,
        current:
          cond do
            assigns.current_path == assigns.navigate -> "page"
            Url.in_section?(assigns.current_path, assigns.navigate) -> "true"
            true -> nil
          end
      )

    ~H"""
    <li class="flex min-w-0 flex-1">
      <.link
        id={@id}
        navigate={@navigate}
        aria-current={@current}
        class="flex min-w-0 flex-1 flex-col items-center justify-center gap-tight text-xs focus-visible:-outline-offset-2"
      >
        <span class={[
          "flex h-control-sm w-14 items-center justify-center rounded-full transition-colors [&_svg]:size-icon",
          @current && "bg-accent-bg text-accent",
          !@current && "text-text-muted"
        ]}>
          {render_slot(@inner_block)}
        </span>
        <span class={[
          "max-w-full truncate",
          @current && "font-semibold text-text",
          !@current && "text-text-muted"
        ]}>
          {@label}
        </span>
      </.link>
    </li>
    """
  end
end
