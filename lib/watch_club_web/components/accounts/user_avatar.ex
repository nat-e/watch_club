defmodule WatchClubWeb.Components.Accounts.UserAvatar do
  @moduledoc """
  A User's avatar, or a blank one once they're deleted, and their name.
  """
  use WatchClubWeb, :component

  attr :user, User, default: nil, doc: "nil once the User is deleted"
  attr :size, :string, values: ~w(xs sm md lg), default: "md"
  attr :class, :any, default: nil

  def user_avatar(%{user: nil} = assigns) do
    ~H"""
    <span
      role="img"
      aria-label={username(nil)}
      title={username(nil)}
      class={[
        "relative flex shrink-0 items-center justify-center rounded-full bg-surface-raised text-text-subtle",
        @size == "xs" && "size-4 [&_svg]:size-3",
        @size == "sm" && "size-5 [&_svg]:size-3.5",
        @size == "md" && "size-7 [&_svg]:size-4",
        @size == "lg" && "size-10 [&_svg]:size-6",
        @class
      ]}
    >
      <Lucideicons.user_round />
    </span>
    """
  end

  def user_avatar(assigns) do
    ~H"""
    <.avatar id={@user.id} name={@user.username} size={@size} class={@class} />
    """
  end

  @doc """
  The User's Username, or "Deleted user" once they're deleted.
  """
  @spec username(User.t() | nil) :: String.t()
  def username(nil), do: dgettext("default", "Deleted user")
  def username(%User{username: username}), do: username
end
