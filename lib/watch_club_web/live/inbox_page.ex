defmodule WatchClubWeb.InboxPage do
  @moduledoc """
  The Inbox, where a User sees their Conversations. Empty until Conversations exist.
  """
  use WatchClubWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      title={dgettext("nav", "Inbox")}
    >
    </Layouts.app>
    """
  end
end
