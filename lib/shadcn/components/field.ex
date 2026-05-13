defmodule Shadcn.Components.Field do
  @moduledoc """
  Layout primitives for accessible forms — labels, descriptions, errors,
  legends, separators.

      <.field>
        <.field_label for="email">Email</.field_label>
        <WatchClubWeb.UI.Input.input id="email" type="email" />
        <.field_description>We'll never share your email.</.field_description>
      </.field>

      <.field_set>
        <.field_legend>Notifications</.field_legend>
        <.field_description>Choose how to be notified.</.field_description>
        <.field_group>
          <.field orientation="horizontal">
            <.checkbox id="push" />
            <.field_label for="push">Push notifications</.field_label>
          </.field>
          <.field orientation="horizontal">
            <.checkbox id="email" />
            <.field_label for="email">Email notifications</.field_label>
          </.field>
        </.field_group>
      </.field_set>

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/field.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/field
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def field_set(assigns) do
    ~H"""
    <fieldset data-slot="field-set" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </fieldset>
    """
  end

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(legend label), default: "legend"
  attr :rest, :global
  slot :inner_block, required: true

  def field_legend(assigns) do
    ~H"""
    <legend data-slot="field-legend" data-variant={@variant} class={@class} {@rest}>
      {render_slot(@inner_block)}
    </legend>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def field_group(assigns) do
    ~H"""
    <div data-slot="field-group" class={["group/field-group", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :orientation, :string, values: ~w(vertical horizontal responsive), default: "vertical"
  attr :invalid, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def field(assigns) do
    ~H"""
    <div
      role="group"
      data-slot="field"
      data-orientation={@orientation}
      data-invalid={@invalid || nil}
      data-disabled={@disabled || nil}
      class={["group/field", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def field_content(assigns) do
    ~H"""
    <div data-slot="field-content" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :for, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def field_label(assigns) do
    ~H"""
    <label data-slot="field-label" for={@for} class={@class} {@rest}>
      {render_slot(@inner_block)}
    </label>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def field_title(assigns) do
    ~H"""
    <div data-slot="field-title" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def field_description(assigns) do
    ~H"""
    <p data-slot="field-description" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block

  def field_separator(assigns) do
    has_content = assigns.inner_block != []
    assigns = assign(assigns, :has_content, has_content)

    ~H"""
    <div data-slot="field-separator" data-content={@has_content} class={@class} {@rest}>
      <div data-slot="field-separator-line" />
      <span :if={@has_content} data-slot="field-separator-content">
        {render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :errors, :list, default: []
  attr :rest, :global
  slot :inner_block

  def field_error(assigns) do
    ~H"""
    <%= if @inner_block != [] or @errors != [] do %>
      <div role="alert" data-slot="field-error" class={@class} {@rest}>
        <%= cond do %>
          <% @inner_block != [] -> %>
            {render_slot(@inner_block)}
          <% length(@errors) == 1 -> %>
            {hd(@errors)}
          <% true -> %>
            <ul class="ml-4 flex list-disc flex-col gap-1">
              <li :for={e <- @errors}>{e}</li>
            </ul>
        <% end %>
      </div>
    <% end %>
    """
  end
end
