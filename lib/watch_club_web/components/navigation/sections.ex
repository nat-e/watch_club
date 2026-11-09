defmodule WatchClubWeb.Components.Navigation.Sections do
  @moduledoc """
  The app's sections, in the order the sidebar and the phone tabs show them.
  """
  use WatchClubWeb, :verified_routes
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.User
  alias WatchClubWeb.Helpers.Url

  @doc """
  Each section's id, name, icon, page, the other pages it holds besides the ones under its page,
  how many things the User hasn't seen in it, what that count is for screen readers, and whether
  it has a phone tab. The phone tabs leave the others to the You page.
  """
  def sections(%User{} = user) do
    [
      %{
        id: "home",
        label: dgettext("nav", "Home"),
        icon: :house,
        navigate: ~p"/",
        pages: [],
        badge: 0,
        badge_label: nil,
        phone?: true
      },
      %{
        id: "browse",
        label: dgettext("nav", "Browse"),
        icon: :clapperboard,
        navigate: ~p"/browse",
        pages: [~p"/search"],
        badge: 0,
        badge_label: nil,
        phone?: true
      },
      %{
        id: "playlists",
        label: dgettext("nav", "Playlists"),
        icon: :list,
        navigate: ~p"/playlists",
        pages: [],
        badge: user.shared_unseen_playlist_count,
        badge_label:
          dngettext(
            "nav",
            "%{count} playlist newly shared with you",
            "%{count} playlists newly shared with you",
            user.shared_unseen_playlist_count
          ),
        phone?: true
      },
      %{
        id: "inbox",
        label: dgettext("nav", "Inbox"),
        icon: :inbox,
        navigate: ~p"/inbox",
        pages: [],
        badge: user.unread_conversation_count,
        badge_label:
          dngettext(
            "nav",
            "%{count} unread conversation",
            "%{count} unread conversations",
            user.unread_conversation_count
          ),
        phone?: true
      },
      %{
        id: "requests",
        label: dgettext("nav", "Requests"),
        icon: :download,
        navigate: ~p"/my-requests",
        pages: [],
        badge: user.ready_unseen_request_count,
        badge_label:
          dngettext(
            "nav",
            "%{count} new request ready to watch",
            "%{count} new requests ready to watch",
            user.ready_unseen_request_count
          ),
        phone?: false
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
end
