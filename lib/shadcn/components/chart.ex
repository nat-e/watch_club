defmodule Shadcn.Components.Chart do
  @moduledoc """
  Themed container for charts.

      <.chart_container id="sales" config={%{"sales" => %{label: "Sales", color: "var(--primary)"}}}>
        <%!-- Inject your SVG, canvas, or chart-library output here --%>
        <svg width="100%" height="200">...</svg>
      </.chart_container>

  shadcn's React chart depends on `recharts`. Phoenix LiveView has no
  equivalent built-in, so this port only provides the **container +
  theming infrastructure** — author the actual chart in HEEx (SVG) or
  via a JS hook with your charting lib of choice.

  The `config` map becomes CSS variables on the container (one per series),
  so chart authors can `fill: var(--color-sales)` in their SVG.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/chart.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/chart
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :config, :map, default: %{}, doc: "%{key => %{label, color}}"
  attr :rest, :global

  slot :inner_block, required: true

  def chart_container(assigns) do
    style =
      assigns.config
      |> Enum.map_join("; ", fn {k, %{color: color}} -> "--color-#{k}: #{color}" end)

    assigns = assign(assigns, :chart_style, style)

    ~H"""
    <div
      id={@id}
      data-slot="chart"
      data-chart={@id}
      style={@chart_style}
      class={["group/chart", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :config, :map, required: true
  attr :rest, :global

  def chart_legend(assigns) do
    ~H"""
    <div data-slot="chart-legend" class={@class} {@rest}>
      <div :for={{k, %{label: label}} <- @config} data-slot="chart-legend-item">
        <span data-slot="chart-legend-swatch" style={"background-color: var(--color-#{k})"} />
        {label}
      </div>
    </div>
    """
  end
end
