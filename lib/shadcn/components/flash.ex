defmodule Shadcn.Components.Flash do
  @moduledoc """
  Toast notifications driven by Phoenix's flash map.

  Place a single `<.flash flash={@flash} />` in your root layout.
  Each non-empty entry of the flash map renders as a stacked toast card.
  Closing a toast — by click or auto-dismiss — pushes `lv:clear-flash`
  so server state matches the DOM.

      <.flash flash={@flash} position="top-right" />

  Variants are derived from the flash kind: `:success`, `:info`,
  `:warning`, `:error`. Anything else falls back to the default style.

  Ported from Shadcn on 2026-04-29
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/sonner.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/sonner
  """
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @kinds [:success, :info, :warning, :error]

  attr :id, :string, default: "flash"
  attr :flash, :map, required: true

  attr :position, :string,
    values: ~w(top-left top-center top-right bottom-left bottom-center bottom-right),
    default: "bottom-right"

  attr :duration, :integer,
    default: 5000,
    doc: "auto-dismiss delay in ms; 0 disables the timer"

  attr :kinds, :list,
    default: @kinds,
    doc: "ordered list of flash kinds to render (top of the stack first)"

  attr :class, :any, default: nil
  attr :rest, :global

  def flash(assigns) do
    ~H"""
    <div
      id={@id}
      data-slot="flash"
      data-position={@position}
      role="region"
      aria-label="Notifications"
      class={@class}
      {@rest}
    >
      <.flash_toast
        :for={{kind, msg} <- visible_toasts(@flash, @kinds)}
        id={"#{@id}-#{kind}"}
        kind={kind}
        message={msg}
        duration={@duration}
      />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :kind, :atom, required: true
  attr :message, :string, required: true
  attr :duration, :integer, required: true

  defp flash_toast(assigns) do
    ~H"""
    <div
      id={@id}
      data-slot="flash-toast"
      data-variant={@kind}
      data-duration={@duration}
      role={if @kind == :error, do: "alert", else: "status"}
      phx-hook=".AutoDismiss"
    >
      <.toast_icon kind={@kind} />
      <div data-slot="flash-toast-content">
        <div data-slot="flash-toast-title">{@message}</div>
      </div>
      <button
        type="button"
        data-slot="flash-toast-close"
        aria-label="Close"
        phx-click={
          JS.push("lv:clear-flash", value: %{key: @kind})
          |> JS.hide(
            to: "##{@id}",
            time: 200,
            transition: {"transition-opacity ease-in duration-200", "opacity-100", "opacity-0"}
          )
        }
      >
        <Lucideicons.x />
      </button>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".AutoDismiss">
        export default {
          mounted() { this.start() },
          updated() { this.start() },
          destroyed() { clearTimeout(this.t) },
          start() {
            clearTimeout(this.t)
            const ms = parseInt(this.el.dataset.duration, 10)
            if (ms > 0) this.t = setTimeout(() => this.el.querySelector('[data-slot="flash-toast-close"]')?.click(), ms)
          },
        }
      </script>
    </div>
    """
  end

  defp toast_icon(%{kind: :success} = assigns),
    do: ~H|<Lucideicons.circle_check data-slot="flash-toast-icon" />|

  defp toast_icon(%{kind: :info} = assigns),
    do: ~H|<Lucideicons.info data-slot="flash-toast-icon" />|

  defp toast_icon(%{kind: :warning} = assigns),
    do: ~H|<Lucideicons.triangle_alert data-slot="flash-toast-icon" />|

  defp toast_icon(%{kind: :error} = assigns),
    do: ~H|<Lucideicons.octagon_x data-slot="flash-toast-icon" />|

  defp toast_icon(assigns), do: ~H||

  defp visible_toasts(flash, kinds) do
    for kind <- kinds, msg = Phoenix.Flash.get(flash, kind), do: {kind, msg}
  end
end
