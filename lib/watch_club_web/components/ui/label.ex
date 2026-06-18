defmodule WatchClubWeb.Components.UI.Label do
  @moduledoc """
  Token-driven Watch Club form label primitive.
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
      class={[
        "flex w-fit items-center gap-related text-xs font-medium tracking-wide uppercase text-text select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:text-text-disabled peer-disabled:cursor-not-allowed peer-disabled:text-text-disabled",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </label>
    """
  end
end
