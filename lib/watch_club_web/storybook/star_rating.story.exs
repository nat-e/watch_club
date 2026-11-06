defmodule WatchClubWeb.Storybook.StarRating do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.Contents.StarRating

  def function, do: &StarRating.star_rating/1

  def template do
    """
    <div class="p-4 text-sm text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :english,
        description: "In English",
        attributes: %{rating: 7.3, locale: :en_US}
      },
      %Variation{
        id: :french,
        description: "In French, with a decimal comma",
        attributes: %{rating: 7.3, locale: :fr_FR}
      },
      %Variation{
        id: :whole,
        description: "A whole number keeps its decimal",
        attributes: %{rating: 8.0, locale: :en_US}
      }
    ]
  end
end
