defmodule WatchClubWeb.Components.UI.Tooltip do
  @moduledoc """
  Token-driven Watch Club tooltip primitive.

  Uses the native Popover API for top-layer rendering so tooltips can escape
  clipped containers such as dialogs. A small colocated hook owns disclosure and
  positioning next to the trigger.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :class, :any, default: "relative inline-flex"
  attr :content_class, :any, default: nil

  attr :side, :string,
    values: ~w(top bottom),
    default: "top",
    doc: "Preferred tooltip side. The tooltip flips vertically when needed."

  attr :rest, :global

  slot :trigger, required: true do
    attr :class, :any
  end

  slot :inner_block, required: true

  def tooltip(assigns) do
    assigns = assign(assigns, :trigger_slot, List.first(assigns.trigger))

    ~H"""
    <%!--
      The hook owns popover visibility and positioning only. Content remains
      LiveView-owned; ignore only the inline style written while positioning.
    --%>
    <div
      id={@id}
      data-slot="tooltip"
      class={@class}
      phx-hook=".Tooltip"
      phx-mounted={JS.ignore_attributes("style", to: "##{@id}-content")}
      {@rest}
    >
      <span
        id={"#{@id}-trigger"}
        data-slot="tooltip-trigger"
        class={["contents", @trigger_slot[:class]]}
      >
        {render_slot(@trigger_slot)}
      </span>

      <div
        id={"#{@id}-content"}
        data-slot="tooltip-content"
        data-side={@side}
        popover="manual"
        role="tooltip"
        class={[
          "pointer-events-none fixed inset-auto z-50 m-0 max-w-[min(20rem,calc(100vw-2rem))] rounded-control border border-border bg-surface-overlay px-related py-tight text-sm leading-6 text-text shadow-overlay outline-none",
          @content_class
        ]}
      >
        {render_slot(@inner_block)}
      </div>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Tooltip">
      function isOpen(popover) {
        return popover.matches(":popover-open");
      }

      function triggerControl(trigger) {
        const focusable = trigger.querySelector(
          "button:not([disabled]),a[href],input:not([disabled]),select:not([disabled]),textarea:not([disabled]),[role='button'],[tabindex]:not([tabindex='-1'])"
        );
        if (focusable) return focusable;

        for (const child of trigger.children) {
          const rect = child.getBoundingClientRect();
          if (rect.width > 0 || rect.height > 0) return child;
        }

        return trigger.firstElementChild || trigger;
      }

      function appendDescribedBy(element, id) {
        const ids = (element.getAttribute("aria-describedby") || "")
          .split(/\s+/)
          .filter(Boolean);

        if (!ids.includes(id)) ids.push(id);

        element.setAttribute("aria-describedby", ids.join(" "));
      }

      export default {
        mounted() {
          this.hovered = false;
          this.focused = false;
          this.open = this.open.bind(this);
          this.close = this.close.bind(this);
          this.maybeClose = this.maybeClose.bind(this);
          this.onPointerEnter = this.onPointerEnter.bind(this);
          this.onPointerLeave = this.onPointerLeave.bind(this);
          this.onFocusIn = this.onFocusIn.bind(this);
          this.onFocusOut = this.onFocusOut.bind(this);
          this.onKeyDown = this.onKeyDown.bind(this);
          this.position = this.position.bind(this);
          this.refreshRefs();
        },
        updated() {
          this.refreshRefs();
        },
        destroyed() {
          this.close();
          this.removeListeners();
          this.removePositionListeners();
        },
        refreshRefs() {
          this.removeListeners();
          this.removePositionListeners();

          this.trigger = this.el.querySelector(':scope > [data-slot="tooltip-trigger"]');
          this.triggerControl = triggerControl(this.trigger);
          this.content = this.el.querySelector(':scope > [data-slot="tooltip-content"]');

          appendDescribedBy(this.triggerControl, this.content.id);

          this.triggerControl.addEventListener("pointerenter", this.onPointerEnter);
          this.triggerControl.addEventListener("pointerleave", this.onPointerLeave);
          this.triggerControl.addEventListener("focusin", this.onFocusIn);
          this.triggerControl.addEventListener("focusout", this.onFocusOut);
          this.triggerControl.addEventListener("keydown", this.onKeyDown);
        },
        removeListeners() {
          this.triggerControl?.removeEventListener("pointerenter", this.onPointerEnter);
          this.triggerControl?.removeEventListener("pointerleave", this.onPointerLeave);
          this.triggerControl?.removeEventListener("focusin", this.onFocusIn);
          this.triggerControl?.removeEventListener("focusout", this.onFocusOut);
          this.triggerControl?.removeEventListener("keydown", this.onKeyDown);
        },
        open() {
          if (!this.content || isOpen(this.content)) return;

          this.content.style.visibility = "hidden";
          this.content.showPopover();
          this.position();
          this.content.style.removeProperty("visibility");
          this.addPositionListeners();
        },
        close() {
          if (!this.content || !isOpen(this.content)) return;

          this.content.hidePopover();
          this.removePositionListeners();
        },
        maybeClose() {
          if (this.hovered || this.focused) return;

          this.close();
        },
        onPointerEnter() {
          this.hovered = true;
          this.open();
        },
        onPointerLeave() {
          this.hovered = false;
          this.maybeClose();
        },
        onFocusIn() {
          this.focused = true;
          this.open();
        },
        onFocusOut(event) {
          if (this.triggerControl?.contains(event.relatedTarget)) return;

          this.focused = false;
          this.maybeClose();
        },
        onKeyDown(event) {
          if (event.key !== "Escape") return;

          this.hovered = false;
          this.focused = false;
          this.close();
        },
        addPositionListeners() {
          if (this.positionListenersAdded) return;

          this.positionListenersAdded = true;
          window.addEventListener("resize", this.position);
          window.addEventListener("scroll", this.position, true);
        },
        removePositionListeners() {
          if (!this.positionListenersAdded) return;

          this.positionListenersAdded = false;
          window.removeEventListener("resize", this.position);
          window.removeEventListener("scroll", this.position, true);
        },
        position() {
          if (!this.triggerControl || !this.content || !isOpen(this.content)) return;

          const anchor = this.triggerControl.getBoundingClientRect();
          const tooltip = this.content.getBoundingClientRect();
          const margin = 8;
          const offset = 8;

          const topFits = anchor.top >= tooltip.height + offset + margin;
          const bottomFits = window.innerHeight - anchor.bottom >= tooltip.height + offset + margin;
          let side = this.content.dataset.side || "top";

          if (side === "top" && !topFits && bottomFits) side = "bottom";
          if (side === "bottom" && !bottomFits && topFits) side = "top";

          let left = anchor.left + anchor.width / 2 - tooltip.width / 2;
          let top = side === "bottom" ? anchor.bottom + offset : anchor.top - tooltip.height - offset;

          left = Math.max(margin, Math.min(left, window.innerWidth - tooltip.width - margin));
          top = Math.max(margin, Math.min(top, window.innerHeight - tooltip.height - margin));

          this.content.style.left = `${left}px`;
          this.content.style.top = `${top}px`;
        },
      };
    </script>
    """
  end
end
