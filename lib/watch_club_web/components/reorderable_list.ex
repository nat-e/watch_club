defmodule WatchClubWeb.Components.ReorderableList do
  @moduledoc """
  A generic sortable list component backed by SortableJS.
  """
  use WatchClubWeb, :component

  attr :id, :string, required: true
  attr :items, :list, required: true
  attr :item_id, :any, required: true
  attr :event, :string, default: "reorder"
  attr :target, :any, default: nil
  attr :class, :any, default: nil
  attr :item_class, :any, default: nil
  attr :rest, :global

  slot :item, required: true

  def reorderable_list(assigns) do
    assigns = assign(assigns, :items_with_index, Enum.with_index(assigns.items))

    ~H"""
    <ul
      id={@id}
      class={@class}
      phx-hook=".Sortable"
      phx-target={@target}
      data-sortable-event={@event}
      {@rest}
    >
      <li
        :for={{item, index} <- @items_with_index}
        id={"#{@id}-#{item_id(item, @item_id)}"}
        data-sortable-id={item_id(item, @item_id)}
        class={@item_class}
      >
        {render_slot(@item, {item, index})}
      </li>
    </ul>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Sortable">
      import Sortable from "sortablejs";

      export default {
        mounted() {
          this.sortable = Sortable.create(this.el, {
            animation: 150,
            dataIdAttr: "data-sortable-id",
            draggable: "[data-sortable-id]",
            handle: "[data-sortable-handle]",
            ghostClass: "opacity-50",
            chosenClass: "opacity-50",
            forceFallback: true,

            onEnd: (event) => {
              if (event.oldIndex === event.newIndex) return;
              this.pushOrder();
            },
          });
        },

        destroyed() {
          this.sortable?.destroy();
        },

        pushOrder() {
          const event = this.el.dataset.sortableEvent || "reorder";
          const payload = { ids: this.sortable.toArray() };

          if (this.el.getAttribute("phx-target")) {
            this.pushEventTo(this.el, event, payload);
          } else {
            this.pushEvent(event, payload);
          }
        },
      };
    </script>
    """
  end

  defp item_id(item, item_id) when is_function(item_id, 1), do: item_id.(item)
  defp item_id(item, item_id) when is_atom(item_id), do: Map.fetch!(item, item_id)
end
