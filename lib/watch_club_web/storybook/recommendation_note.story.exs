defmodule WatchClubWeb.Storybook.RecommendationNote do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.Conversations.RecommendationNote

  def function, do: &RecommendationNote.recommendation_note/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{
          body: "The ending got me for days. Watch it without reading anything about it."
        }
      }
    ]
  end
end
