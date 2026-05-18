defmodule WatchClubWeb.Components.UI.Modal do
  @moduledoc """
  Token-driven Watch Club modal primitive.

  Renders the native `<dialog>` shell and dialog content layout in one
  component. The modal is meant to be rendered only while it is open, and
  `on_close` keeps LiveView state in sync when the user dismisses it with
  Escape, a backdrop click, the close button, or any descendant marked with
  `data-modal-close`.
  """

  use Phoenix.Component
  use Gettext, backend: WatchClubWeb.Gettext

  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :class, :any, default: nil

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md",
    doc: "Maximum modal width."

  attr :on_close, JS, required: true
  attr :rest, :global

  slot :title, required: true do
    attr :class, :any
  end

  slot :description do
    attr :class, :any
  end

  slot :footer do
    attr :class, :any
  end

  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <dialog
      id={@id}
      open={true}
      role="dialog"
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
      aria-describedby={@description != [] && "#{@id}-description"}
      data-slot="modal"
      data-on-close={@on_close}
      class={[
        "fixed top-1/2 left-1/2 z-50 m-0 max-h-[calc(100dvh-2rem)] w-full max-w-[calc(100%-2rem)] -translate-x-1/2 -translate-y-1/2 overflow-hidden rounded-card border border-border bg-surface-overlay p-0 text-text shadow-overlay outline-none backdrop:bg-canvas/70 backdrop:backdrop-blur-sm",
        @size == "sm" && "sm:max-w-md",
        @size == "md" && "sm:max-w-lg",
        @size == "lg" && "sm:max-w-2xl",
        @class
      ]}
      phx-hook=".Modal"
      phx-mounted={JS.ignore_attributes("open")}
      {@rest}
    >
      <div
        data-slot="modal-content"
        class="grid max-h-[calc(100dvh-2rem)] gap-cluster overflow-y-auto p-cluster text-sm text-text"
      >
        <header data-slot="modal-header" class="grid gap-related pr-10">
          <h2
            :for={title <- @title}
            id={"#{@id}-title"}
            data-slot="modal-title"
            class={["text-lg font-semibold leading-none", title[:class]]}
          >
            {render_slot(title)}
          </h2>

          <p
            :for={description <- @description}
            id={"#{@id}-description"}
            data-slot="modal-description"
            class={[
              "text-sm text-text-muted text-pretty [&_a]:underline [&_a]:underline-offset-4 [&_a]:hover:text-text",
              description[:class]
            ]}
          >
            {render_slot(description)}
          </p>
        </header>

        <div data-slot="modal-body" class="grid gap-group text-sm/relaxed text-text">
          {render_slot(@inner_block)}
        </div>

        <footer
          :for={footer <- @footer}
          data-slot="modal-footer"
          class={["flex flex-col-reverse gap-related sm:flex-row sm:justify-end", footer[:class]]}
        >
          {render_slot(footer)}
        </footer>
      </div>

      <button
        type="button"
        data-modal-close
        data-slot="modal-close"
        aria-label={dgettext("default", "Close")}
        class="absolute top-group right-group inline-flex size-control-sm items-center justify-center rounded-control border border-transparent text-text-muted transition-colors outline-none hover:bg-surface-hover hover:text-text focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-border-focus/40 [&_svg]:size-icon-sm"
      >
        <Lucideicons.x />
      </button>
    </dialog>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Modal">
      function openModal(el) {
        if (!el.open) {
          el.showModal();
        }
      }

      function clickedBackdrop(event, dialog) {
        if (event.target !== dialog) {
          return false;
        }

        const rect = dialog.getBoundingClientRect();

        return (
          event.clientX < rect.left ||
          event.clientX > rect.right ||
          event.clientY < rect.top ||
          event.clientY > rect.bottom
        );
      }

      function setup() {
        this.onClick = this.onClick.bind(this);
        this.onClose = this.onClose.bind(this);

        this.el.addEventListener("click", this.onClick);
        this.el.addEventListener("close", this.onClose);
      }

      function teardown() {
        this.el.removeEventListener("click", this.onClick);
        this.el.removeEventListener("close", this.onClose);
      }

      export default {
        mounted() {
          this.closed = false;
          setup.call(this);

          // Server-rendered with `open`; remove it first so showModal() can create
          // a proper modal dialog with focus handling and Escape-to-close.
          this.el.removeAttribute("open");
          openModal(this.el);
        },
        updated() {
          if (!this.closed) {
            openModal(this.el);
          }
        },
        destroyed() {
          teardown.call(this);
        },
        onClick(event) {
          if (event.target.closest("[data-modal-close]")) {
            event.preventDefault();
            this.closed = true;
            this.el.close();
            return;
          }

          if (clickedBackdrop(event, this.el)) {
            this.closed = true;
            this.el.close();
          }
        },
        onClose() {
          this.closed = true;
          const js = this.el.getAttribute("data-on-close");

          if (js) {
            this.liveSocket.execJS(this.el, js);
          }
        },
      };
    </script>
    """
  end
end
