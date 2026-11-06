defmodule WatchClubWeb.Components.Accounts.UserAvatar do
  @moduledoc """
  A User's avatar, or a blank one once they're deleted, and their name.
  """
  use WatchClubWeb, :component

  attr :user, User, default: nil, doc: "nil once the User is deleted"
  attr :size, :string, values: ~w(xs sm md lg), default: "md"
  attr :class, :any, default: nil

  def user_avatar(assigns) do
    ~H"""
    <.avatar id={@user && @user.id} name={username(@user)} size={@size} class={@class} />
    """
  end

  @doc """
  The User's Username, or "Deleted user" once they're deleted.
  """
  @spec username(User.t() | nil) :: String.t()
  def username(nil), do: dgettext("default", "Deleted user")
  def username(%User{username: username}), do: username
end
