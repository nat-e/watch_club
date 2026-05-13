defmodule Shadcn.Storybook.Label do
  use PhoenixStorybook.Story, :component

  def function, do: &Shadcn.Components.Label.label/1

  def template do
    """
    <div class="grid w-full max-w-sm gap-2">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{for: "email"},
        slots: ["Email"]
      }
    ]
  end
end
