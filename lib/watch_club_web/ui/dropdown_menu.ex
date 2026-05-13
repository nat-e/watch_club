defmodule WatchClubWeb.UI.DropdownMenu do
  @moduledoc """
  Token-driven Watch Club dropdown menu primitive.

  Uses the native Popover API for top-layer rendering and dismissal. A small
  colocated hook only positions the popover next to its trigger.
  """

  use Phoenix.Component

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  slot :trigger, required: true
  slot :inner_block, required: true

  def dropdown_menu(assigns) do
    assigns =
      assign(assigns, :id, assigns.id || "dropdown-menu-#{System.unique_integer([:positive])}")

    ~H"""
    <div
      id={@id}
      data-slot="dropdown-menu"
      class={["relative inline-flex", @class]}
      phx-hook=".DropdownMenu"
      {@rest}
    >
      <span id={"#{@id}-trigger"} data-slot="dropdown-menu-trigger" class="contents">
        {render_slot(@trigger)}
      </span>

      <div
        id={"#{@id}-content"}
        data-slot="dropdown-menu-content"
        popover="auto"
        role="menu"
        aria-orientation="vertical"
        tabindex="-1"
        class="fixed inset-auto z-50 m-0 max-h-[min(24rem,calc(100vh-4rem))] min-w-48 overflow-y-auto rounded-control border border-border bg-surface-overlay p-1 text-text shadow-overlay outline-none"
      >
        {render_slot(@inner_block)}
      </div>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".DropdownMenu">
      function triggerControl(trigger) {
        const focusable = trigger.querySelector("button,a,[role='button'],[tabindex]");
        if (focusable) return focusable;

        for (const child of trigger.children) {
          const rect = child.getBoundingClientRect();
          if (rect.width > 0 || rect.height > 0) return child;
        }

        return trigger.firstElementChild || trigger;
      }

      function isOpen(popover) {
        return popover.matches(":popover-open");
      }

      export default {
        mounted() {
          this.onTriggerClick = this.onTriggerClick.bind(this);
          this.onContentClick = this.onContentClick.bind(this);
          this.onToggle = this.onToggle.bind(this);
          this.position = this.position.bind(this);
          this.refreshRefs();
        },
        updated() {
          this.refreshRefs();
        },
        destroyed() {
          this.removeListeners();
          this.removePositionListeners();
        },
        refreshRefs() {
          this.removeListeners();

          this.trigger = this.el.querySelector(':scope > [data-slot="dropdown-menu-trigger"]');
          this.triggerControl = triggerControl(this.trigger);
          this.content = this.el.querySelector(':scope > [data-slot="dropdown-menu-content"]');

          this.triggerControl.setAttribute("aria-haspopup", "menu");
          this.triggerControl.setAttribute("aria-controls", this.content.id);
          this.triggerControl.setAttribute("aria-expanded", isOpen(this.content) ? "true" : "false");

          this.trigger.addEventListener("click", this.onTriggerClick);
          this.content.addEventListener("click", this.onContentClick);
          this.content.addEventListener("toggle", this.onToggle);
        },
        removeListeners() {
          this.trigger?.removeEventListener("click", this.onTriggerClick);
          this.content?.removeEventListener("click", this.onContentClick);
          this.content?.removeEventListener("toggle", this.onToggle);
        },
        onTriggerClick(event) {
          event.preventDefault();

          if (isOpen(this.content)) {
            this.content.hidePopover();
          } else {
            this.content.style.visibility = "hidden";
            this.content.showPopover();
            this.position();
            this.content.style.removeProperty("visibility");
          }
        },
        onContentClick(event) {
          const item = event.target.closest('[data-slot="dropdown-menu-item"]');

          if (!item) return;
          if (item.disabled || item.getAttribute("aria-disabled") === "true") {
            event.preventDefault();
            event.stopPropagation();
            return;
          }

          this.content.hidePopover();
        },
        onToggle(event) {
          const open = event.newState === "open";
          this.triggerControl.setAttribute("aria-expanded", open ? "true" : "false");

          if (open) {
            this.position();
            this.addPositionListeners();
          } else {
            this.removePositionListeners();
          }
        },
        addPositionListeners() {
          window.addEventListener("resize", this.position);
          window.addEventListener("scroll", this.position, true);
        },
        removePositionListeners() {
          window.removeEventListener("resize", this.position);
          window.removeEventListener("scroll", this.position, true);
        },
        position() {
          if (!this.triggerControl || !this.content || !isOpen(this.content)) return;

          const anchor = this.triggerControl.getBoundingClientRect();
          const menu = this.content.getBoundingClientRect();
          const margin = 8;
          const offset = 8;

          let left = anchor.right - menu.width;
          let top = anchor.bottom + offset;

          if (top + menu.height > window.innerHeight - margin && anchor.top > menu.height + offset + margin) {
            top = anchor.top - menu.height - offset;
          }

          left = Math.max(margin, Math.min(left, window.innerWidth - menu.width - margin));
          top = Math.max(margin, Math.min(top, window.innerHeight - menu.height - margin));

          this.content.style.left = `${left}px`;
          this.content.style.top = `${top}px`;
        },
      };
    </script>
    """
  end

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(default destructive), default: "default"
  attr :disabled, :boolean, default: false

  attr :rest, :global, include: ~w(href navigate patch method download replace target)

  slot :inner_block, required: true

  def dropdown_menu_item(%{rest: rest} = assigns)
      when is_map_key(rest, :href) or is_map_key(rest, :navigate) or is_map_key(rest, :patch) do
    ~H"""
    <.link
      role="menuitem"
      data-slot="dropdown-menu-item"
      data-variant={@variant}
      aria-disabled={@disabled || nil}
      class={item_class(@variant, @disabled, @class)}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def dropdown_menu_item(assigns) do
    ~H"""
    <button
      type="button"
      role="menuitem"
      data-slot="dropdown-menu-item"
      data-variant={@variant}
      disabled={@disabled}
      class={item_class(@variant, @disabled, @class)}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  def dropdown_menu_separator(assigns) do
    ~H"""
    <div
      data-slot="dropdown-menu-separator"
      role="separator"
      aria-orientation="horizontal"
      class={["-mx-1 my-1 h-px bg-border-subtle", @class]}
      {@rest}
    />
    """
  end

  defp item_class(variant, disabled, class) do
    [
      "flex min-h-9 w-full items-center gap-2 rounded-control px-2.5 py-2 text-left text-sm outline-none transition-colors select-none [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
      disabled && "pointer-events-none text-text-disabled opacity-50",
      !disabled && variant == "default" &&
        "text-text hover:bg-surface-hover focus-visible:bg-surface-hover",
      !disabled &&
        variant == "destructive" &&
        "text-danger hover:bg-danger-bg focus-visible:bg-danger-bg",
      class
    ]
  end
end
