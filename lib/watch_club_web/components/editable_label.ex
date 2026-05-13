defmodule WatchClubWeb.Components.EditableLabel do
  @moduledoc """
  An inline editable text label.

  The edit state is fully client-side. When the input blurs, the component sends
  the configured event only if the value changed.
  """
  use WatchClubWeb, :component

  attr :id, :string, required: true
  attr :value, :string, required: true
  attr :event, :string, required: true
  attr :payload, :map, default: %{}
  attr :target, :any, default: nil
  attr :label, :string, default: nil
  attr :class, :any, default: nil
  attr :text_class, :any, default: nil
  attr :button_class, :any, default: nil
  attr :input_class, :any, default: nil
  attr :rest, :global

  def editable_label(assigns) do
    assigns =
      assigns
      |> assign(:encoded_payload, Jason.encode!(assigns.payload))
      |> assign(:input_label, assigns.label || assigns.value)

    ~H"""
    <div
      id={@id}
      phx-hook=".EditableLabel"
      phx-target={@target}
      data-editable-label-event={@event}
      data-editable-label-value={@value}
      data-editable-label-payload={@encoded_payload}
      class={@class}
      {@rest}
    >
      <.inline data-editable-label-display class="min-w-0">
        <span data-editable-label-text class={@text_class}>{@value}</span>
        <button
          type="button"
          data-editable-label-edit
          class={[
            "inline-flex size-8 shrink-0 items-center justify-center rounded-control text-text-muted hover:text-text",
            @button_class
          ]}
          aria-label={@input_label}
        >
          <Lucideicons.pencil class="size-4" />
        </button>
      </.inline>

      <input
        data-editable-label-input
        type="text"
        value={@value}
        class={[
          "h-9 w-full min-w-0 rounded-control border border-border bg-transparent px-related py-tight text-sm outline-none focus-visible:ring-2 focus-visible:ring-border-focus focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
          @input_class
        ]}
        aria-label={@input_label}
        hidden
      />
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".EditableLabel">
      export default {
        mounted() {
          this.display = this.el.querySelector("[data-editable-label-display]");
          this.text = this.el.querySelector("[data-editable-label-text]");
          this.editButton = this.el.querySelector("[data-editable-label-edit]");
          this.input = this.el.querySelector("[data-editable-label-input]");
          this.editing = false;
          this.syncValueFromDOM();

          this.onEditClick = (event) => {
            event.preventDefault();
            this.openInput();
          };

          this.onInputBlur = () => {
            if (!this.editing) return;
            this.closeInput({ save: true });
          };

          this.onInputKeyDown = (event) => {
            if (event.key === "Escape") {
              event.preventDefault();
              this.closeInput({ save: false });
            }

            if (event.key === "Enter") {
              event.preventDefault();
              this.input.blur();
            }
          };

          this.onDocumentPointerDown = (event) => {
            if (this.editing && !this.el.contains(event.target)) {
              this.input.blur();
            }
          };

          this.editButton.addEventListener("click", this.onEditClick);
          this.input.addEventListener("blur", this.onInputBlur);
          this.input.addEventListener("keydown", this.onInputKeyDown);
          document.addEventListener("pointerdown", this.onDocumentPointerDown, true);
        },

        updated() {
          if (!this.editing) {
            this.syncValueFromDOM();
          }
        },

        destroyed() {
          this.editButton.removeEventListener("click", this.onEditClick);
          this.input.removeEventListener("blur", this.onInputBlur);
          this.input.removeEventListener("keydown", this.onInputKeyDown);
          document.removeEventListener("pointerdown", this.onDocumentPointerDown, true);
        },

        openInput() {
          if (this.editing) return;

          this.editing = true;
          this.input.value = this.value;
          this.display.hidden = true;
          this.input.hidden = false;

          requestAnimationFrame(() => {
            this.input.focus();
            this.input.select();
          });
        },

        closeInput({ save }) {
          const nextValue = this.input.value;
          const previousValue = this.value;

          this.editing = false;
          this.input.hidden = true;
          this.display.hidden = false;

          if (save && nextValue !== previousValue) {
            this.value = nextValue;
            this.text.textContent = nextValue;
            this.pushChange(nextValue);
          } else {
            this.input.value = previousValue;
          }
        },

        pushChange(value) {
          const event = this.el.dataset.editableLabelEvent;
          const payload = { ...this.payload(), value };

          if (this.el.getAttribute("phx-target")) {
            this.pushEventTo(this.el, event, payload);
          } else {
            this.pushEvent(event, payload);
          }
        },

        payload() {
          try {
            return JSON.parse(this.el.dataset.editableLabelPayload || "{}");
          } catch (_error) {
            return {};
          }
        },

        syncValueFromDOM() {
          this.value = this.el.dataset.editableLabelValue || "";
          this.input.value = this.value;
          this.text.textContent = this.value;
        },
      };
    </script>
    """
  end
end
