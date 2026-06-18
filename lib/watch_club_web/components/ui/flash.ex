defmodule WatchClubWeb.Components.UI.Flash do
  @moduledoc """
  Token-driven Watch Club flash/toast primitive.
  """

  use Phoenix.Component
  use Gettext, backend: WatchClubWeb.Gettext

  alias Phoenix.LiveView.JS

  @kinds [:success, :info, :warning, :error]

  attr :id, :string, default: "flash"
  attr :flash, :map, required: true

  attr :position, :string,
    values: ~w(top-left top-center top-right bottom-left bottom-center bottom-right),
    default: "bottom-right"

  attr :duration, :integer, default: 5000, doc: "auto-dismiss delay in ms; 0 disables the timer"
  attr :kinds, :list, default: @kinds, doc: "ordered list of flash kinds to render"
  attr :class, :any, default: nil
  attr :style, :any, default: nil
  attr :rest, :global

  def flash(assigns) do
    ~H"""
    <%!--
      The TopLayer hook only promotes this container to the browser top layer;
      LiveView still owns the toast children, so this intentionally avoids
      phx-update="ignore".
    --%>
    <div
      id={@id}
      data-slot="flash"
      data-position={@position}
      popover="manual"
      role="region"
      aria-label={dgettext("default", "Notifications")}
      class={@class}
      style={
        "pointer-events: none; position: fixed; inset: auto; z-index: 100; margin: 0; display: flex; width: 360px; max-width: calc(100% - 2rem); flex-direction: column; gap: 0.5rem; overflow: visible; border: 0; background: transparent; padding: 0; " <>
          (case @position do
             "top-left" -> "top: 1rem; left: 1rem"
             "top-center" -> "top: 1rem; left: 50%; transform: translateX(-50%)"
             "top-right" -> "top: 1rem; right: 1rem"
             "bottom-left" -> "bottom: 1rem; left: 1rem"
             "bottom-center" -> "bottom: 1rem; left: 50%; transform: translateX(-50%)"
             "bottom-right" -> "right: 1rem; bottom: 1rem"
           end) <>
          if(@style in [nil, ""], do: "", else: "; #{to_string(@style)}")
      }
      phx-hook=".TopLayer"
      {@rest}
    >
      <.flash_toast
        :for={{kind, message} <- visible_toasts(@flash, @kinds)}
        id={"#{@id}-#{kind}"}
        kind={kind}
        message={message}
        duration={@duration}
      />

      <script :type={Phoenix.LiveView.ColocatedHook} name=".TopLayer">
        export default {
          mounted() { this.show() },
          updated() { this.show() },
          show() { try { this.el.showPopover() } catch (_) {} },
        };
      </script>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :kind, :atom, required: true
  attr :message, :string, required: true
  attr :duration, :integer, required: true

  defp flash_toast(assigns) do
    ~H"""
    <%!--
      The AutoDismiss hook owns only a timer. The toast markup remains
      LiveView-owned, so this intentionally avoids phx-update="ignore".
    --%>
    <div
      id={@id}
      data-slot="flash-toast"
      data-variant={@kind}
      data-duration={@duration}
      role={if @kind == :error, do: "alert", else: "status"}
      class={[
        "pointer-events-auto relative grid w-full grid-cols-[auto_1fr_auto] items-start gap-related rounded-control border px-group py-related text-sm shadow-overlay transition-opacity duration-200",
        @kind == :success && "border-success-border bg-success-bg text-success",
        @kind == :info && "border-info-border bg-info-bg text-info",
        @kind == :warning && "border-warning-border bg-warning-bg text-warning",
        @kind == :error && "border-danger-border bg-danger-bg text-danger",
        @kind not in [:success, :info, :warning, :error] &&
          "border-border bg-surface-overlay text-text"
      ]}
      phx-hook=".AutoDismiss"
    >
      <.toast_icon kind={@kind} />

      <div data-slot="flash-toast-content" class="flex min-w-0 flex-col gap-tight">
        <div data-slot="flash-toast-title" class="font-medium wrap-break-word">{@message}</div>
      </div>

      <button
        id={"#{@id}-close"}
        type="button"
        data-slot="flash-toast-close"
        aria-label={dgettext("default", "Close")}
        class={[
          "-mt-0.5 -mr-1 inline-flex size-icon-lg shrink-0 items-center justify-center rounded-control transition-colors outline-none focus-visible:ring-2 [&_svg]:size-icon-sm",
          @kind == :error && "text-danger hover:bg-danger-bg focus-visible:ring-danger-ring",
          @kind != :error &&
            "text-text-muted hover:bg-surface-hover hover:text-text focus-visible:ring-focus-ring"
        ]}
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
        };
      </script>
    </div>
    """
  end

  defp toast_icon(%{kind: :success} = assigns),
    do:
      ~H|<Lucideicons.circle_check data-slot="flash-toast-icon" class="mt-0.5 size-icon-sm text-success" />|

  defp toast_icon(%{kind: :info} = assigns),
    do:
      ~H|<Lucideicons.info data-slot="flash-toast-icon" class="mt-0.5 size-icon-sm text-info" />|

  defp toast_icon(%{kind: :warning} = assigns),
    do:
      ~H|<Lucideicons.triangle_alert data-slot="flash-toast-icon" class="mt-0.5 size-icon-sm text-warning" />|

  defp toast_icon(%{kind: :error} = assigns),
    do:
      ~H|<Lucideicons.octagon_x data-slot="flash-toast-icon" class="mt-0.5 size-icon-sm text-danger" />|

  defp toast_icon(assigns), do: ~H||

  defp visible_toasts(flash, kinds) do
    for kind <- kinds, message = Phoenix.Flash.get(flash, kind), do: {kind, message}
  end
end
