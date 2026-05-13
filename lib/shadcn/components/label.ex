defmodule Shadcn.Components.Label do
  @moduledoc """
  Form field label. Tie text to an input via `for`.

      <.label for="email">Email</.label>
      <WatchClubWeb.UI.Input.input id="email" name="email" type="email" />

  Or pass a `Phoenix.HTML.FormField` via `field` to derive the `for` attribute:

      <.label field={@form[:email]}>Email</.label>
      <WatchClubWeb.UI.Input.input field={@form[:email]} type="email" />

  The label dims when its associated input is disabled (via `peer-disabled:*`
  on a sibling `peer` input).

  Ported from Shadcn on 2026-04-27
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/label.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/label
  Radix doc: https://www.radix-ui.com/primitives/docs/components/label
  """
  use Phoenix.Component

  attr :for, :string, default: nil
  attr :field, Phoenix.HTML.FormField, doc: "form field — derives `for` from field.id"
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def label(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, for: assigns.for || field.id)
    |> label()
  end

  def label(assigns) do
    ~H"""
    <label
      data-slot="label"
      for={@for}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </label>
    """
  end
end
