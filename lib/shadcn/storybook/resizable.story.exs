defmodule Shadcn.Storybook.Resizable do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Resizable

  def function, do: &Resizable.resizable_panels/1

  defp container_template(content) do
    """
    <div class="h-[300px] w-[600px] rounded-md border">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :horizontal,
        attributes: %{id: "rzh"},
        slots: [
          ~s|<:panel default_size={30}><div class="flex size-full items-center justify-center text-sm">Sidebar</div></:panel>|,
          ~s|<:panel><div class="flex size-full items-center justify-center text-sm">Main content</div></:panel>|
        ]
      },
      %Variation{
        id: :vertical,
        attributes: %{id: "rzv", direction: "vertical"},
        slots: [
          ~s|<:panel default_size={40}><div class="flex size-full items-center justify-center text-sm">Top</div></:panel>|,
          ~s|<:panel><div class="flex size-full items-center justify-center text-sm">Bottom</div></:panel>|
        ]
      }
    ]
  end
end
