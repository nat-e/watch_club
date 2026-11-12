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
        id: :photo,
        description: "With a photo, shown instead of the letter",
        attributes: %{
          id: "user-jane",
          name: "Jane Doe",
          src: "https://image.tmdb.org/t/p/w185/6uFaCOupDTPRnTiedveTUvjOikC.jpg"
        }
      },
      %Variation{
        id: :extra_large,
        description: "Extra large, as the photo heading Settings",
        attributes: %{id: "user-jane", name: "Jane Doe", size: "xl"}
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
            %{id: "user-books", name: "Ben", src: "https://image.tmdb.org/t/p/w185/6uFaCOupDTPRnTiedveTUvjOikC.jpg"},
            %{id: "user-series", name: "Clara"},
            %{id: "user-games", name: "Daniel"}
          ]}
        />
        """
      }
    ]
  end
end
