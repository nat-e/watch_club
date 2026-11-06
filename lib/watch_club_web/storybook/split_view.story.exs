defmodule WatchClubWeb.Storybook.SplitView do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.SplitView

  def function, do: &SplitView.split_view/1

  def imports, do: [{WatchClubWeb.Components.UI.Button, [button: 1]}]

  # The layout's main column is the container it switches on
  def template, do: main_column("w-full")

  defp main_column(width) do
    """
    <div class="@container/main h-96 #{width} overflow-hidden text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :list,
        description:
          "Nothing open: narrow screens show the list, with its main action floating on phones",
        attributes: %{open: false},
        slots: example_slots()
      },
      %Variation{
        id: :open,
        description: "Something open: narrow screens show it instead of the list",
        attributes: %{open: true},
        slots: example_slots()
      },
      %Variation{
        id: :wide,
        description: "A wide main column: the list beside what's open",
        attributes: %{open: true},
        slots: example_slots(),
        template: main_column("w-[60rem]")
      }
    ]
  end

  defp example_slots do
    [
      ~s|<:list><p class="px-group text-sm">The list</p></:list>|,
      ~s|<:detail><p class="px-group text-sm">What's open</p></:detail>|,
      ~s|<:fab><.button id="split-view-story-fab">New</.button></:fab>|
    ]
  end
end
