defmodule WatchClubWeb.Storybook.UnreadBadge do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.UnreadBadge

  def function, do: &UnreadBadge.unread_badge/1

  def variations do
    [
      %Variation{id: :some, attributes: %{count: 3}},
      %Variation{id: :none, description: "Nothing shows at 0", attributes: %{count: 0}}
    ]
  end
end
