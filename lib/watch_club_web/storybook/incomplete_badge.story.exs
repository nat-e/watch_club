defmodule WatchClubWeb.Storybook.IncompleteBadge do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.Contents.IncompleteBadge

  def function, do: &IncompleteBadge.incomplete_badge/1

  def template do
    """
    <div class="p-4 text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :incomplete,
        description: "On an Incomplete TV Show's poster: an aired TV Show Episode has no Media",
        attributes: %{id: "incomplete"}
      }
    ]
  end
end
