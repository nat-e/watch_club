defmodule WatchClubWeb.Components.Navigation.Sections do
  @moduledoc """
  The app's sections, in the order the sidebar and the phone tabs show them.
  """
  use WatchClubWeb, :verified_routes
  use Gettext, backend: WatchClubWeb.Gettext
  use Phoenix.Component

  import WatchClubWeb.Components.UI.Badge

  alias WatchClub.Accounts.User
  alias WatchClubWeb.Helpers.Url

  @doc """
  Each section's id, name, icon, page, the other pages it holds besides the ones under its page,
  and the count its badge shows, hidden at 0.
  """
  def sections(%User{} = user) do
    [
      %{
        id: "browse",
        label: dgettext("nav", "Browse"),
        icon: :clapperboard,
        navigate: ~p"/",
        pages: [~p"/search"],
        badge: 0
      },
      %{
        id: "playlists",
        label: dgettext("nav", "Playlists"),
        icon: :list,
        navigate: ~p"/lists",
        pages: [],
        badge: 0
      },
      %{
        id: "inbox",
        label: dgettext("nav", "Inbox"),
        icon: :inbox,
        navigate: ~p"/inbox",
        pages: [],
        badge: 0
      },
      %{
        id: "requests",
        label: dgettext("nav", "Requests"),
        icon: :download,
        navigate: ~p"/my-requests",
        pages: [],
        badge: user.ready_unseen_request_count
      }
    ]
  end

  @doc """
  The `aria-current` of a section's link: `"page"` on its page, `"true"` on the other pages it
  holds, `nil` elsewhere.
  """
  def aria_current(%{navigate: path}, path), do: "page"

  def aria_current(section, path) do
    if Url.in_section?(path, section.navigate) or path in section.pages, do: "true"
  end

  attr :count, :integer, required: true
  attr :class, :any, default: nil

  @doc """
  A section's badge: its count, read as "2 new".
  """
  def section_badge(assigns) do
    ~H"""
    <.badge :if={@count > 0} variant="accent" size="sm" class={@class}>
      <span aria-hidden="true">{@count}</span>
      <span class="sr-only">{dngettext("nav", "%{count} new", "%{count} new", @count)}</span>
    </.badge>
    """
  end
end
