defmodule WatchClubWeb.Storybook.ProblemCategory do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Playbacks.ProblemReport.Category
  alias WatchClubWeb.Components.Playbacks.ProblemCategory

  def function, do: &ProblemCategory.problem_category/1

  def variations do
    [
      %VariationGroup{
        id: :categories,
        description: "Every category",
        variations:
          for category <- Category.values() do
            %Variation{id: category, attributes: %{category: category}}
          end
      }
    ]
  end
end
