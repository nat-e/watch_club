defmodule WatchClubWeb.Components.UI.Badges do
  @moduledoc """
  A collection of Badges and similar inline components for displaying a Resource in a
  standardized manner
  """
  use Phoenix.Component
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.User

  attr :user, User

  @doc """
  An inline user span
  """
  def user_ref(%{user: nil} = assigns) do
    ~H"""
    <span class="font-semibold text-text-subtle">{dgettext("default", "Deleted user")}</span>
    """
  end

  def user_ref(assigns) do
    ~H"""
    <span class="font-semibold text-primary">@{@user.username}</span>
    """
  end
end
