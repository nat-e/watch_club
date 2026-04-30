defmodule Shadcn.Components.Slider do
  @moduledoc """
  Single-thumb, range, or multi-thumb slider.

      <.slider id="volume" name="volume" value={50} />
      <.slider id="range" name="range" value={[25, 75]} />
      <.slider id="multi" name="multi" value={[10, 40, 80]} />
      <.slider id="vol" orientation="vertical" value={30} class="h-40" />

  Renders a custom track + per-thumb hidden `<input type="range">` for form
  submission and accessibility. When `value` is a list of length > 1, the
  inputs use `name="<name>[]"` so the form submits a list. Drag, click, and
  keyboard interaction are provided by `slider.js`.

  `min_steps_between_thumbs` enforces a minimum gap between adjacent thumbs.

  Ported from Shadcn on 2026-04-29
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/slider.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/slider
  Radix doc: https://www.radix-ui.com/primitives/docs/components/slider
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :min, :integer, default: 0
  attr :max, :integer, default: 100
  attr :step, :integer, default: 1
  attr :orientation, :string, values: ~w(horizontal vertical), default: "horizontal"
  attr :disabled, :boolean, default: false
  attr :min_steps_between_thumbs, :integer, default: 0
  attr :rest, :global

  def slider(assigns) do
    values =
      case assigns.value do
        nil -> [assigns.min, assigns.max]
        v when is_list(v) -> v
        v -> [v]
      end

    input_name =
      case {assigns.name, length(values)} do
        {nil, _} -> nil
        {name, 1} -> name
        {name, _} -> "#{name}[]"
      end

    assigns = assign(assigns, values: values, input_name: input_name)

    ~H"""
    <div
      id={@id}
      data-slot="slider"
      data-orientation={@orientation}
      data-disabled={@disabled || nil}
      data-min-steps-between-thumbs={@min_steps_between_thumbs}
      phx-hook="SliderHook"
      class={["group/slider", @class]}
      {@rest}
    >
      <input
        :for={{v, i} <- Enum.with_index(@values)}
        type="range"
        name={@input_name}
        value={v}
        min={@min}
        max={@max}
        step={@step}
        disabled={@disabled}
        data-slot="slider-input"
        data-thumb-index={i}
        aria-orientation={@orientation}
      />
      <span data-slot="slider-track" aria-hidden="true">
        <span data-slot="slider-range" />
      </span>
      <span
        :for={i <- 0..(length(@values) - 1)}
        data-slot="slider-thumb"
        data-thumb-index={i}
        aria-hidden="true"
      />
    </div>
    """
  end
end
