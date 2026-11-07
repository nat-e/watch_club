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
        id: :blank,
        description: "Without an id, as for a deleted User",
        attributes: %{id: nil, name: "Deleted user"}
      },
      %Variation{
        id: :group,
        description: "Avatar group",
        template: """
        <.avatar_group
          avatars={[
            %{id: "user-cinema", name: "Alice"},
            %{id: "user-books", name: "Ben"},
            %{id: "user-series", name: "Clara"},
            %{id: "user-games", name: "Daniel"}
          ]}
        />
        """
      }
    ]
  end
end
