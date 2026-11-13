defmodule WatchClubWeb.Storybook.UserAvatarGroup do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Accounts.User
  alias WatchClubWeb.Components.Accounts.UserAvatar

  def function, do: &UserAvatar.user_avatar_group/1

  def variations do
    [
      %Variation{
        id: :users,
        attributes: %{
          users: [
            %User{id: "user-jane", username: "jane"},
            %User{id: "user-ben", username: "ben"}
          ],
          avatar_size: "sm"
        }
      },
      %Variation{
        id: :more,
        description: "Past three Users, how many more",
        attributes: %{
          users: [
            %User{id: "user-jane", username: "jane"},
            %User{id: "user-ben", username: "ben"},
            %User{id: "user-clara", username: "clara"},
            nil
          ],
          avatar_size: "sm"
        }
      }
    ]
  end
end
