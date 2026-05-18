defmodule WatchClubWeb.Components.UI.SegmentedControl do
  @moduledoc """
  Token-driven Watch Club segmented control primitive.
  """

  use Phoenix.Component

  import WatchClubWeb.Components.UI.Button

  attr :class, :any, default: nil
  attr :rest, :global

  slot :item, required: true do
    attr :selected, :boolean
    attr :href, :string
    attr :navigate, :string
    attr :patch, :string
    attr :replace, :boolean
    attr :class, :any
  end

  def segmented_control(assigns) do
    ~H"""
    <div
      class={[
        "inline-flex w-full overflow-hidden rounded-control border border-border bg-surface-inset text-sm",
        @class
      ]}
      {@rest}
    >
      <.segmented_control_item :for={item <- @item} item={item} />
    </div>
    """
  end

  attr :item, :any, required: true

  defp segmented_control_item(assigns) do
    item_attrs = item_attrs(assigns.item)

    assigns =
      assigns
      |> assign(:item_attrs, item_attrs)
      |> assign(:selected?, assigns.item[:selected] == true)
      |> assign(:link?, map_size(item_attrs) > 0)

    ~H"""
    <.button
      type="button"
      variant="ghost"
      aria-current={@link? && @selected? && "page"}
      aria-pressed={!@link? && @selected?}
      class={[
        "grow basis-0 !rounded-none !border-0 text-center",
        @selected? &&
          "pointer-events-none !bg-surface-selected !text-text hover:!bg-surface-selected active:!bg-surface-selected",
        @item[:class]
      ]}
      {@item_attrs}
    >
      {render_slot(@item)}
    </.button>
    """
  end

  defp item_attrs(item) do
    attrs =
      [:href, :navigate, :patch]
      |> Enum.reduce(%{}, fn attr, attrs ->
        case item[attr] do
          nil -> attrs
          value -> Map.put(attrs, attr, value)
        end
      end)

    if map_size(attrs) > 0 && item[:replace] do
      Map.put(attrs, :replace, true)
    else
      attrs
    end
  end
end
