defmodule Shadcn.Storybook.Spinner do
  use PhoenixStorybook.Story, :component

  def function, do: &Shadcn.Components.Spinner.spinner/1

  def variations do
    [
      %Variation{
        id: :spinner,
        description: "Spinner",
        template: """
        <div class="flex items-center gap-4">
          <.spinner />
        </div>
        """
      }
    ]
  end
end
