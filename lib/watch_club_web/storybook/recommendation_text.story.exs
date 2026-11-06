defmodule WatchClubWeb.Storybook.RecommendationText do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.Conversations.RecommendationText

  def function, do: &RecommendationText.recommendation_text/1

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
