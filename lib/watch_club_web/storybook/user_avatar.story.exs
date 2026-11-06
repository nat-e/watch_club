defmodule WatchClubWeb.Storybook.UserAvatar do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Accounts.User
  alias WatchClubWeb.Components.Accounts.UserAvatar

  def function, do: &UserAvatar.user_avatar/1

  def variations do
    [
      %Variation{
        id: :user,
        attributes: %{user: %User{id: "user-jane", username: "jane"}}
      },
      %Variation{
        id: :deleted,
        description: "A deleted User",
        attributes: %{user: nil}
      }
    ]
  end
end
