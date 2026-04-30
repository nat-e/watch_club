defmodule Shadcn.Components.Resizable do
  @moduledoc """
  Split panel with a draggable divider between panes.

      <.resizable_panels id="layout">
        <:panel default_size={30}>
          <div class="flex h-full items-center justify-center">Sidebar</div>
        </:panel>
        <:panel>
          <div class="flex h-full items-center justify-center">Main</div>
        </:panel>
      </.resizable_panels>

  Two-pane only; no nested groups, no fixed min sizes (use CSS for that).
  The hook drags the divider and updates flex-basis on the panes.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/resizable.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/resizable
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :direction, :string, values: ~w(horizontal vertical), default: "horizontal"
  attr :rest, :global

  slot :panel do
    attr :default_size, :integer
    attr :class, :any
  end

  def resizable_panels(assigns) do
    ~H"""
    <div
      id={@id}
      data-slot="resizable-group"
      data-direction={@direction}
      phx-hook="ResizableHook"
      class={["group/resizable", @class]}
      {@rest}
    >
      <%= for {p, i} <- Enum.with_index(@panel) do %>
        <%= if i > 0 do %>
          <div
            data-slot="resizable-handle"
            role="separator"
            tabindex="0"
            aria-orientation={@direction}
          >
            <div data-slot="resizable-handle-grip" />
          </div>
        <% end %>
        <div
          data-slot="resizable-panel"
          data-panel-index={i}
          style={panel_style(p[:default_size], length(@panel))}
          class={p[:class]}
        >
          {render_slot(p)}
        </div>
      <% end %>
    </div>
    """
  end

  defp panel_style(nil, count), do: "flex: 1 1 #{trunc(100 / count)}%;"
  defp panel_style(size, _), do: "flex: 1 1 #{size}%;"
end
