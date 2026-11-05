defmodule WatchClubWeb.Components.Navigation.Sections do
  @moduledoc """
  The app's sections, in the order the sidebar and the phone tabs show them.
  """
  use WatchClubWeb, :verified_routes
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClubWeb.Helpers.Url

  @doc """
  Each section's id, name, icon, page, and the other pages it holds besides the ones under its
  page.
  """
  def sections do
    [
      %{
        id: "browse",
        label: dgettext("nav", "Browse"),
        icon: :clapperboard,
        navigate: ~p"/",
        pages: [~p"/search"]
      },
      %{id: "playlists", label: dgettext("nav", "Playlists"), icon: :list, navigate: ~p"/lists"},
      %{id: "inbox", label: dgettext("nav", "Inbox"), icon: :inbox, navigate: ~p"/inbox"},
      %{
        id: "requests",
        label: dgettext("nav", "Requests"),
        icon: :download,
        navigate: ~p"/my-requests"
      }
    ]
  end

  @doc """
  The `aria-current` of a section's link: `"page"` on its page, `"true"` on the other pages it
  holds, `nil` elsewhere.
  """
  def current(%{navigate: path}, path), do: "page"

  def current(section, path) do
    if Url.in_section?(path, section.navigate) or path in Map.get(section, :pages, []),
      do: "true"
  end
end
