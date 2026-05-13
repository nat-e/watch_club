defmodule WatchClubWeb.Storybook.DesignSystem.Avatar do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.UI.Avatar

  def function, do: &Avatar.avatar/1

  def imports, do: [{WatchClubWeb.UI.Avatar, [avatar_group: 1]}]

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{id: "user-jane", name: "Jane Doe"}
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes via class",
        template: """
        <div class="flex items-center gap-3">
          <.psb-variation />
        </div>
        """,
        variations: [
          %Variation{
            id: :small,
            attributes: %{id: "club-small", name: "Small Club", class: "size-6 text-xs"}
          },
          %Variation{id: :default, attributes: %{id: "club-default", name: "Default Club"}},
          %Variation{
            id: :large,
            attributes: %{id: "club-large", name: "Large Club", class: "size-12 text-base"}
          }
        ]
      },
      %Variation{
        id: :group,
        description: "1–3 avatars render all; 4+ renders the first two and an overflow count.",
        template: """
        <.avatar_group
          avatars={[
            %{id: "club-cinema", name: "Cinema Club"},
            %{id: "club-books", name: "Book Club"},
            %{id: "club-series", name: "Series Club"},
            %{id: "club-games", name: "Game Club"}
          ]}
          avatar_class="size-6 text-xs"
        />
        """
      }
    ]
  end
end
