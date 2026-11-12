defmodule WatchClubWeb.Components.Accounts.UserAvatar do
  @moduledoc """
  A User's avatar, with their photo or their letter, or a blank one once they're deleted, and
  their name. Every User's avatar goes through these components, which alone know photos' URLs.
  """
  use WatchClubWeb, :component

  attr :user, User, default: nil, doc: "nil once the User is deleted"
  attr :size, :string, values: ~w(xs sm md lg xl), default: "md"
  attr :class, :any, default: nil
  attr :rest, :global

  def user_avatar(assigns) do
    ~H"""
    <.avatar
      id={@user && @user.id}
      name={username(@user)}
      src={photo_url(@user)}
      size={@size}
      class={@class}
      {@rest}
    />
    """
  end

  attr :users, :list, required: true, doc: "nil for a deleted User"
  attr :avatar_size, :string, values: ~w(xs sm md lg), default: "md"
  attr :avatar_class, :any, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  @doc "Overlapping avatars, the first three Users' or two and how many more"
  def user_avatar_group(assigns) do
    ~H"""
    <.avatar_group
      avatars={Enum.map(@users, &%{id: &1 && &1.id, name: username(&1), src: photo_url(&1)})}
      avatar_size={@avatar_size}
      avatar_class={@avatar_class}
      class={@class}
      {@rest}
    />
    """
  end

  @doc """
  The User's Username, or "Deleted user" once they're deleted.
  """
  @spec username(User.t() | nil) :: String.t()
  def username(nil), do: dgettext("default", "Deleted user")
  def username(%User{username: username}), do: username

  defp photo_url(%User{photo_revision: revision}) when is_binary(revision),
    do: ~p"/users/photos/#{revision}"

  defp photo_url(_no_photo), do: nil
end
