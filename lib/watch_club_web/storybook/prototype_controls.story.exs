defmodule WatchClubWeb.Storybook.PrototypeControls do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.Prototypes.Controls

  def function, do: &Controls.prototype_controls/1

  def variations do
    [
      %Variation{
        id: :experiment,
        description:
          "A flask button in the top bar's right corner toggles the panel under it, closed when the page opens.",
        attributes: %{
          id: "prototype-controls-experiment",
          title: "Watch or request"
        },
        slots: [
          ~s(<p class="text-sm text-text-muted">Variation pickers and sample data go here.</p>)
        ]
      }
    ]
  end
end
