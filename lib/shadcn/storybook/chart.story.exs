defmodule Shadcn.Storybook.Chart do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Chart

  def function, do: &Chart.chart_container/1
  def imports, do: [{Shadcn.Components.Chart, [chart_legend: 1]}]

  defp container_template(content) do
    """
    <div class="w-[520px]">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  @config %{
    "desktop" => %{label: "Desktop", color: "var(--chart-1, oklch(60% 0.2 260))"},
    "mobile" => %{label: "Mobile", color: "var(--chart-2, oklch(70% 0.18 160))"}
  }

  defp legend_slot do
    inspected = inspect(@config, limit: :infinity)
    ~s|<.chart_legend config={#{inspected}} />|
  end

  def variations do
    [
      %Variation{
        id: :svg_bars,
        description: "Inline SVG bar chart wired to chart variables",
        attributes: %{id: "ch-bars", config: @config},
        slots: [
          """
          <svg viewBox="0 0 300 150" class="w-full">
            <%= for {x, h} <- [{20, 80}, {70, 120}, {120, 60}, {170, 100}, {220, 90}] do %>
              <rect x={x} y={150 - h} width="20" height={h} fill="var(--color-desktop)" />
              <rect x={x + 25} y={150 - h * 0.6} width="20" height={h * 0.6} fill="var(--color-mobile)" />
            <% end %>
          </svg>
          """,
          legend_slot()
        ]
      }
    ]
  end
end
