defmodule WatchClubWeb.UI.Select do
  @moduledoc """
  Token-driven Watch Club select primitive.

  Renders a button trigger and a floating listbox. A hidden input carries the
  selected value for forms and LiveView change events.
  """

  use Phoenix.Component

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :trigger_class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :placeholder, :string, default: "Select..."

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md"

  attr :disabled, :boolean, default: false
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField, doc: "form field — derives id, name, value, and errors"
  attr :side, :string, values: ~w(top right bottom left), default: "bottom"
  attr :align, :string, values: ~w(start center end), default: "start"
  attr :side_offset, :integer, default: 6
  attr :align_offset, :integer, default: 0
  attr :rest, :global

  slot :inner_block, required: true

  def select(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: field.name,
      value: input_value(field.value),
      errors: errors
    )
    |> select()
  end

  def select(assigns) do
    assigns = assign(assigns, :id, assigns.id || "select-#{System.unique_integer([:positive])}")

    ~H"""
    <div
      id={@id}
      data-slot="select"
      data-state="closed"
      data-side={@side}
      data-align={@align}
      data-side-offset={@side_offset}
      data-align-offset={@align_offset}
      data-disabled={@disabled || nil}
      phx-hook=".Select"
      class={["relative inline-block", @class]}
      {@rest}
    >
      <input type="hidden" name={@name} value={input_value(@value)} data-slot="select-input" />

      <button
        type="button"
        data-slot="select-trigger"
        data-size={@size}
        data-placeholder
        data-placeholder-text={@placeholder}
        aria-haspopup="listbox"
        aria-expanded="false"
        aria-invalid={(@errors != [] && "true") || nil}
        disabled={@disabled}
        class={[
          "flex w-full min-w-0 items-center justify-between gap-2 rounded-control border border-border bg-surface-inset px-3 text-left text-sm text-text shadow-xs transition-[background-color,border-color,box-shadow,color] outline-none",
          "hover:bg-surface-hover focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-border-focus/40",
          "disabled:pointer-events-none disabled:cursor-not-allowed disabled:border-border-subtle disabled:text-text-disabled disabled:opacity-50",
          "aria-invalid:border-danger-border aria-invalid:ring-2 aria-invalid:ring-danger/30",
          "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
          @size == "sm" && "h-control-sm text-xs",
          @size == "md" && "h-control-md",
          @size == "lg" && "h-control-lg text-base",
          @trigger_class
        ]}
      >
        <div
          data-slot="select-value"
          class="flex min-w-0 flex-1 items-center overflow-hidden text-ellipsis whitespace-nowrap text-text-subtle [&>*]:min-w-0 [&>*]:max-w-full"
        >
          {@placeholder}
        </div>
        <Lucideicons.chevron_down
          data-slot="select-trigger-icon"
          aria-hidden="true"
          class="size-4 text-text-subtle"
        />
      </button>

      <div
        id={"#{@id}-content"}
        data-slot="select-content"
        data-state="closed"
        popover="manual"
        role="listbox"
        tabindex="-1"
        class="fixed inset-auto z-50 m-0 max-h-(--watch-club-select-content-available-height) min-w-(--watch-club-select-trigger-width) overflow-x-hidden overflow-y-auto rounded-control border border-border bg-surface-overlay p-1 text-text shadow-overlay outline-none"
      >
        <div data-slot="select-viewport" class="scroll-my-1">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Select">
      const ITEM_SELECTOR = '[data-slot="select-item"]:not([data-disabled])';
      const ALL_ITEMS_SELECTOR = '[data-slot="select-item"]';

      function enabledItems(content) {
        return Array.from(content.querySelectorAll(ITEM_SELECTOR));
      }

      function oppositeSide(side) {
        return { top: "bottom", bottom: "top", left: "right", right: "left" }[side];
      }

      function transformOrigin(side, align) {
        const v = side === "bottom" ? "top" : side === "top" ? "bottom" : null;
        const h = side === "right" ? "left" : side === "left" ? "right" : null;

        if (v) {
          const x = align === "start" ? "left" : align === "end" ? "right" : "center";
          return `${x} ${v}`;
        }

        const y = align === "start" ? "top" : align === "end" ? "bottom" : "center";
        return `${h} ${y}`;
      }

      function isOpen(popover) {
        return popover?.matches(":popover-open");
      }

      export default {
        mounted() {
          this.onTriggerClick = this.onTriggerClick.bind(this);
          this.onTriggerKey = this.onTriggerKey.bind(this);
          this.onContentClick = this.onContentClick.bind(this);
          this.onContentKey = this.onContentKey.bind(this);
          this.onContentPointerOver = this.onContentPointerOver.bind(this);
          this.onDocPointerDown = this.onDocPointerDown.bind(this);
          this.onDocKey = this.onDocKey.bind(this);
          this.onWindowChange = this.onWindowChange.bind(this);
          this.refreshRefs();
          this.syncDisplay();
        },
        updated() {
          this.refreshRefs();
          this.syncDisplay();
          if (isOpen(this.content)) this.position();
        },
        destroyed() {
          this.removeListeners();
          this.removePositionListeners();
          document.removeEventListener("pointerdown", this.onDocPointerDown, true);
          document.removeEventListener("keydown", this.onDocKey, true);
        },
        refreshRefs() {
          this.removeListeners();

          this.input = this.el.querySelector(':scope > [data-slot="select-input"]');
          this.trigger = this.el.querySelector(':scope > [data-slot="select-trigger"]');
          this.content = this.el.querySelector(':scope > [data-slot="select-content"]');

          this.trigger.setAttribute("aria-controls", this.content.id);
          this.trigger.setAttribute("aria-expanded", isOpen(this.content) ? "true" : "false");

          this.trigger.addEventListener("click", this.onTriggerClick);
          this.trigger.addEventListener("keydown", this.onTriggerKey);
          this.content.addEventListener("click", this.onContentClick);
          this.content.addEventListener("keydown", this.onContentKey);
          this.content.addEventListener("pointerover", this.onContentPointerOver);
        },
        removeListeners() {
          this.trigger?.removeEventListener("click", this.onTriggerClick);
          this.trigger?.removeEventListener("keydown", this.onTriggerKey);
          this.content?.removeEventListener("click", this.onContentClick);
          this.content?.removeEventListener("keydown", this.onContentKey);
          this.content?.removeEventListener("pointerover", this.onContentPointerOver);
        },
        addPositionListeners() {
          window.addEventListener("resize", this.onWindowChange);
          window.addEventListener("scroll", this.onWindowChange, true);
        },
        removePositionListeners() {
          window.removeEventListener("resize", this.onWindowChange);
          window.removeEventListener("scroll", this.onWindowChange, true);
        },
        syncDisplay() {
          const value = this.input.value;
          const valueSpan = this.trigger.querySelector('[data-slot="select-value"]');
          const placeholder = this.trigger.getAttribute("data-placeholder-text") ?? "";

          let selected = null;

          this.content.querySelectorAll(ALL_ITEMS_SELECTOR).forEach((item) => {
            const isSelected = item.getAttribute("data-value") === value;

            if (isSelected) {
              item.setAttribute("data-selected", "true");
              item.setAttribute("aria-selected", "true");
              selected = item;
            } else {
              item.removeAttribute("data-selected");
              item.setAttribute("aria-selected", "false");
            }
          });

          if (selected) {
            const text = selected.querySelector('[data-slot="select-item-text"]');
            valueSpan.innerHTML = text ? text.innerHTML : selected.textContent;
            valueSpan.classList.remove("text-text-subtle");
            this.trigger.removeAttribute("data-placeholder");
          } else {
            valueSpan.textContent = placeholder;
            valueSpan.classList.add("text-text-subtle");
            this.trigger.setAttribute("data-placeholder", "");
          }
        },
        open(focus = "selected") {
          if (isOpen(this.content) || this.trigger.disabled) return;

          this.content.style.visibility = "hidden";
          this.content.showPopover();
          this.el.setAttribute("data-state", "open");
          this.content.setAttribute("data-state", "open");
          this.trigger.setAttribute("aria-expanded", "true");
          this.position();
          this.content.style.removeProperty("visibility");

          document.addEventListener("pointerdown", this.onDocPointerDown, true);
          document.addEventListener("keydown", this.onDocKey, true);
          this.addPositionListeners();
          this.focusItem(focus);
        },
        close({ returnFocus = true } = {}) {
          if (!isOpen(this.content)) return;

          this.content.hidePopover();
          this.el.setAttribute("data-state", "closed");
          this.content.setAttribute("data-state", "closed");
          this.trigger.setAttribute("aria-expanded", "false");

          document.removeEventListener("pointerdown", this.onDocPointerDown, true);
          document.removeEventListener("keydown", this.onDocKey, true);
          this.removePositionListeners();

          if (returnFocus) this.trigger.focus();
        },
        focusItem(focus) {
          const enabled = enabledItems(this.content);
          let target;

          if (focus === "selected") {
            target =
              this.content.querySelector(
                '[data-slot="select-item"][data-selected="true"]:not([data-disabled])',
              ) || enabled[0];
          } else if (focus === "first") {
            target = enabled[0];
          } else if (focus === "last") {
            target = enabled[enabled.length - 1];
          }

          target?.focus();
        },
        position() {
          if (!this.trigger || !this.content || !isOpen(this.content)) return;

          const sideOffset = parseInt(this.el.dataset.sideOffset, 10) || 0;
          const alignOffset = parseInt(this.el.dataset.alignOffset, 10) || 0;
          const align = this.el.dataset.align || "start";
          let side = this.el.dataset.side || "bottom";
          const margin = 8;

          this.content.style.left = "0px";
          this.content.style.top = "0px";
          this.content.style.removeProperty("--watch-club-select-content-available-height");

          const anchor = this.trigger.getBoundingClientRect();
          this.content.style.setProperty("--watch-club-select-trigger-width", `${anchor.width}px`);

          const floating = this.content.getBoundingClientRect();
          const room = {
            top: anchor.top - margin,
            bottom: window.innerHeight - anchor.bottom - margin,
            left: anchor.left - margin,
            right: window.innerWidth - anchor.right - margin,
          };
          const needed = side === "top" || side === "bottom" ? floating.height : floating.width;

          if (room[side] < needed + sideOffset && room[oppositeSide(side)] > room[side]) {
            side = oppositeSide(side);
          }

          let x;
          let y;

          if (side === "bottom" || side === "top") {
            y = side === "bottom" ? anchor.bottom + sideOffset : anchor.top - floating.height - sideOffset;

            if (align === "start") x = anchor.left + alignOffset;
            else if (align === "end") x = anchor.right - floating.width + alignOffset;
            else x = anchor.left + anchor.width / 2 - floating.width / 2 + alignOffset;
          } else {
            x = side === "right" ? anchor.right + sideOffset : anchor.left - floating.width - sideOffset;

            if (align === "start") y = anchor.top + alignOffset;
            else if (align === "end") y = anchor.bottom - floating.height + alignOffset;
            else y = anchor.top + anchor.height / 2 - floating.height / 2 + alignOffset;
          }

          x = Math.max(margin, Math.min(x, window.innerWidth - floating.width - margin));
          y = Math.max(margin, Math.min(y, window.innerHeight - floating.height - margin));

          this.content.style.left = `${x}px`;
          this.content.style.top = `${y}px`;
          this.content.setAttribute("data-side", side);
          this.content.setAttribute("data-align", align);
          this.content.style.setProperty("--watch-club-select-content-transform-origin", transformOrigin(side, align));

          if (side === "bottom" || side === "top") {
            const available =
              side === "bottom"
                ? window.innerHeight - anchor.bottom - sideOffset - margin
                : anchor.top - sideOffset - margin;
            this.content.style.setProperty("--watch-club-select-content-available-height", `${Math.max(0, available)}px`);
          } else {
            this.content.style.setProperty("--watch-club-select-content-available-height", "min(18rem, calc(100vh - 4rem))");
          }
        },
        selectValue(value) {
          if (this.input.value !== value) {
            this.input.value = value;
            this.input.dispatchEvent(new Event("input", { bubbles: true }));
            this.input.dispatchEvent(new Event("change", { bubbles: true }));
            this.syncDisplay();
          }

          this.close();
        },
        onTriggerClick(event) {
          event.preventDefault();
          if (isOpen(this.content)) this.close();
          else this.open();
        },
        onTriggerKey(event) {
          if (event.key === "ArrowDown" || event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            this.open("selected");
          } else if (event.key === "ArrowUp") {
            event.preventDefault();
            this.open("last");
          }
        },
        onContentClick(event) {
          const item = event.target.closest('[data-slot="select-item"]');
          if (!item) return;

          if (item.hasAttribute("data-disabled")) {
            event.preventDefault();
            event.stopPropagation();
            return;
          }

          this.selectValue(item.getAttribute("data-value"));
        },
        onContentKey(event) {
          if (!isOpen(this.content)) return;

          if (event.key === "Escape" || event.key === "Tab") {
            event.preventDefault();
            this.close({ returnFocus: event.key !== "Tab" });
            return;
          }

          const enabled = enabledItems(this.content);
          if (enabled.length === 0) return;

          const index = enabled.indexOf(document.activeElement);

          if (event.key === "ArrowDown") {
            event.preventDefault();
            enabled[index === -1 ? 0 : (index + 1) % enabled.length]?.focus();
          } else if (event.key === "ArrowUp") {
            event.preventDefault();
            enabled[index === -1 ? enabled.length - 1 : (index - 1 + enabled.length) % enabled.length]?.focus();
          } else if (event.key === "Home") {
            event.preventDefault();
            enabled[0]?.focus();
          } else if (event.key === "End") {
            event.preventDefault();
            enabled[enabled.length - 1]?.focus();
          } else if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            const item = document.activeElement;
            if (item?.matches(ITEM_SELECTOR)) this.selectValue(item.getAttribute("data-value"));
          }
        },
        onContentPointerOver(event) {
          if (!isOpen(this.content)) return;
          const item = event.target.closest(ITEM_SELECTOR);
          if (item && item !== document.activeElement) item.focus();
        },
        onDocPointerDown(event) {
          if (!isOpen(this.content)) return;
          if (this.el.contains(event.target) || this.content.contains(event.target)) return;
          this.close({ returnFocus: false });
        },
        onDocKey(event) {
          if (event.key === "Escape" && isOpen(this.content)) {
            event.preventDefault();
            this.close();
          }
        },
        onWindowChange() {
          if (isOpen(this.content)) this.position();
        },
      };
    </script>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def select_group(assigns) do
    ~H"""
    <div data-slot="select-group" role="group" class={["flex flex-col", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def select_label(assigns) do
    ~H"""
    <div
      data-slot="select-label"
      class={["px-2 py-1.5 text-xs font-semibold text-text-muted", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :value, :any, required: true
  attr :class, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def select_item(assigns) do
    ~H"""
    <div
      role="option"
      data-slot="select-item"
      data-value={input_value(@value)}
      data-disabled={@disabled || nil}
      aria-selected="false"
      aria-disabled={@disabled || nil}
      tabindex="-1"
      class={[
        "group/select-item relative flex h-9 w-full cursor-default items-center gap-2 overflow-hidden rounded-control pr-8 pl-2.5 text-left text-sm outline-none transition-colors select-none",
        "focus:bg-surface-hover data-[selected=true]:bg-surface-selected",
        "data-disabled:pointer-events-none data-disabled:text-text-disabled data-disabled:opacity-50",
        "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        @class
      ]}
      {@rest}
    >
      <span
        data-slot="select-item-indicator"
        aria-hidden="true"
        class="pointer-events-none absolute right-2 flex size-4 items-center justify-center text-primary opacity-0 transition-opacity group-data-[selected=true]/select-item:opacity-100"
      >
        <Lucideicons.check />
      </span>
      <span data-slot="select-item-text" class="min-w-0 flex-1 truncate">
        {render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  def select_separator(assigns) do
    ~H"""
    <div
      data-slot="select-separator"
      role="separator"
      aria-orientation="horizontal"
      class={["-mx-1 my-1 h-px bg-border-subtle", @class]}
      {@rest}
    />
    """
  end

  defp input_value(nil), do: ""
  defp input_value(value), do: to_string(value)
end
