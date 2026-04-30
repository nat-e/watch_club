defmodule Shadcn.Components.InputGroup do
  @moduledoc """
  Input field with attached add-ons (icons, text, buttons) on either side.

      <.input_group>
        <.input_group_addon>
          <Lucideicons.search />
        </.input_group_addon>
        <.input_group_input placeholder="Search..." />
      </.input_group>

      <.input_group>
        <.input_group_input placeholder="Username" />
        <.input_group_addon align="inline-end">
          <.input_group_text>@example.com</.input_group_text>
        </.input_group_addon>
      </.input_group>

      <.input_group>
        <.input_group_textarea placeholder="Comment" />
        <.input_group_addon align="block-end">
          <.input_group_button>Send</.input_group_button>
        </.input_group_addon>
      </.input_group>

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/input-group.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/input-group
  """
  use Phoenix.Component

  import Shadcn.Components.Button
  import Shadcn.Components.Input
  import Shadcn.Components.Textarea

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def input_group(assigns) do
    ~H"""
    <div
      role="group"
      data-slot="input-group"
      class={["group/input-group", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil

  attr :align, :string,
    values: ~w(inline-start inline-end block-start block-end),
    default: "inline-start"

  attr :rest, :global
  slot :inner_block, required: true

  def input_group_addon(assigns) do
    ~H"""
    <div role="group" data-slot="input-group-addon" data-align={@align} class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def input_group_text(assigns) do
    ~H"""
    <span data-slot="input-group-text" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :class, :any, default: nil

  attr :rest, :global, include: ~w(name type value placeholder disabled required autocomplete)

  def input_group_input(assigns) do
    ~H"""
    <.input data-slot="input-group-control" class={["input-group-control", @class]} {@rest} />
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(name placeholder rows disabled required)

  def input_group_textarea(assigns) do
    ~H"""
    <.textarea
      data-slot="input-group-control"
      class={["input-group-control input-group-textarea", @class]}
      {@rest}
    />
    """
  end

  attr :class, :any, default: nil
  attr :variant, :string, default: "ghost"
  attr :size, :string, values: ~w(xs sm icon-xs icon-sm), default: "xs"
  attr :rest, :global, include: ~w(disabled type name value)
  slot :inner_block, required: true

  def input_group_button(assigns) do
    ~H"""
    <.button
      type="button"
      variant={@variant}
      size={@size}
      data-input-group-button-size={@size}
      class={["input-group-button", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.button>
    """
  end
end
