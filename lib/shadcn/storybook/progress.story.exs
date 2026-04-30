defmodule Shadcn.Storybook.Progress do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Progress

  def function, do: &Progress.progress/1

  defp container_template(content) do
    """
    <div class="w-[420px]">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{id: :empty, attributes: %{value: 0}},
      %Variation{id: :quarter, attributes: %{value: 25}},
      %Variation{id: :half, attributes: %{value: 50}},
      %Variation{id: :three_quarters, attributes: %{value: 75}},
      %Variation{id: :complete, attributes: %{value: 100}}
    ]
  end
end
