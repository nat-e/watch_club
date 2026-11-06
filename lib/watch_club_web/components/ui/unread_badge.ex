defmodule WatchClubWeb.Components.UI.UnreadBadge do
  @moduledoc """
  How many things the User hasn't seen yet, such as the Inbox's Conversations with unread
  Messages. Nothing shows at 0.
  """
  use Phoenix.Component
  use Gettext, backend: WatchClubWeb.Gettext

  import WatchClubWeb.Components.UI.Badge

  attr :count, :integer, required: true
  attr :class, :any, default: nil

  def unread_badge(assigns) do
    ~H"""
    <.badge
      :if={@count > 0}
      variant="accent"
      size="sm"
      aria-label={dngettext("default", "%{count} unread", "%{count} unread", @count)}
      class={@class}
    >
      {@count}
    </.badge>
    """
  end
end
