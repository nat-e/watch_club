defmodule Shadcn.Components.Progress do
  @moduledoc """
  Progress bar showing completion of a task.

      <.progress value={45} />
      <.progress value={100} max={100} />

  Renders an `aria-valuenow`-driven `<div role="progressbar">`. The fill
  uses a `translateX` transform so the bar grows from the left.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/progress.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/progress
  Radix doc: https://www.radix-ui.com/primitives/docs/components/progress
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :value, :integer, default: 0
  attr :max, :integer, default: 100
  attr :rest, :global

  def progress(assigns) do
    ~H"""
    <div
      data-slot="progress"
      role="progressbar"
      aria-valuemin="0"
      aria-valuemax={@max}
      aria-valuenow={@value}
      data-state={if @value >= @max, do: "complete", else: "loading"}
      class={@class}
      {@rest}
    >
      <div
        data-slot="progress-indicator"
        data-state={if @value >= @max, do: "complete", else: "loading"}
        style={"transform: translateX(-#{100 - percent(@value, @max)}%)"}
      />
    </div>
    """
  end

  defp percent(_value, max) when max <= 0, do: 0

  defp percent(value, max) do
    value
    |> Kernel./(max)
    |> Kernel.*(100)
    |> max(0)
    |> min(100)
  end
end
