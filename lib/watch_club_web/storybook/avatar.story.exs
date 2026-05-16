defmodule WatchClubWeb.Storybook.Avatar do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Avatar

  def function, do: &Avatar.avatar/1

  def imports, do: [{WatchClubWeb.Components.UI.Avatar, [avatar_group: 1]}]

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{id: "user-jane", name: "Jane Doe"}
      },
      %Variation{
        id: :group,
        description: "Avatar group",
        template: """
        <.avatar_group
          avatars={[
            %{id: "club-cinema", name: "Cinema Club"},
            %{id: "club-books", name: "Book Club"},
            %{id: "club-series", name: "Series Club"},
            %{id: "club-games", name: "Game Club"}
          ]}
        />
        """
      }
    ]
  end
end
