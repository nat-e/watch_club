defmodule WatchClubWeb.Components.UI.Modal do
  @moduledoc """
  Token-driven Watch Club modal primitive.

  Renders the native `<dialog>` shell and dialog content layout in one
  component. The modal is meant to be rendered only while it is open, and
  `on_close` keeps LiveView state in sync when the user dismisses it with
  Escape, a backdrop click, the close button, or any descendant marked with
  `data-modal-close`. However it closes, focus returns to the element that had
  it when the modal opened, such as the dropdown menu's trigger.

  Don't mark a submit button with `data-modal-close`: the modal cancels its
  click, so the form never submits. To submit and close, push both events from
  the form, for example
  `phx-submit={JS.push("save") |> JS.push("close_modals", target: @myself)}`.
  """

  use Phoenix.Component
  use Gettext, backend: WatchClubWeb.Gettext

  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :class, :any, default: nil

  attr :size, :string,
    values: ~w(sm md lg none),
    default: "none",
    doc: "Maximum modal width."

  attr :on_close, JS, required: true

  attr :phone, :string,
    values: ~w(centered sheet full_screen),
    default: "centered",
    doc: "How it opens on phones: centered, from the bottom of the screen, or filling the screen."

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
      class={
        [
          "m-auto rounded-card border border-border bg-surface-overlay p-related text-text shadow-modal backdrop:bg-scrim backdrop:backdrop-blur-sm",
          # A column only while open: the browser hides a closed dialog with a display we'd override
          "open:flex open:flex-col",
          @size == "sm" && "sm:max-w-md",
          @size == "md" && "sm:max-w-lg",
          @size == "lg" && "sm:max-w-2xl",
          @phone == "sheet" &&
            "max-md:mb-0 max-md:max-h-[85svh] max-md:w-full max-md:max-w-none! max-md:rounded-b-none",
          @phone == "full_screen" &&
            "max-md:m-0 max-md:h-svh max-md:max-h-svh max-md:w-full max-md:max-w-none! max-md:rounded-none max-md:border-0 max-md:p-0",
          @class
        ]
      }
      phx-hook=".Modal"
      phx-mounted={JS.ignore_attributes("open")}
      {@rest}
    >
      <header
        data-slot="modal-header"
        class={[
          "flex flex-col gap-related pt-cluster pb-cluster",
          @phone == "full_screen" && "px-page",
          @phone != "full_screen" && "px-cluster"
        ]}
      >
        <h2
          :for={title <- @title}
          id={"#{@id}-title"}
          data-slot="modal-title"
          class={["pr-10 text-lg font-semibold leading-tight", title[:class]]}
        >
          {render_slot(title)}
        </h2>

        <p
          :for={description <- @description}
          id={"#{@id}-description"}
          data-slot="modal-description"
          class={[
            "pr-10 text-sm text-text-muted text-pretty [&_a]:underline [&_a]:underline-offset-4 [&_a]:hover:text-text",
            description[:class]
          ]}
        >
          {render_slot(description)}
        </p>
      </header>

      <%!-- Only the body scrolls, so the title, the close button and the footer stay --%>
      <div
        data-slot="modal-body"
        class={[
          "flex min-h-0 flex-col gap-group overflow-y-auto pb-cluster text-sm/relaxed text-text",
          @phone == "full_screen" && "px-page",
          @phone != "full_screen" && "px-cluster"
        ]}
      >
        {render_slot(@inner_block)}
      </div>

      <footer
        :for={footer <- @footer}
        data-slot="modal-footer"
        class={[
          "flex flex-col-reverse gap-related pb-cluster sm:flex-row sm:justify-end",
          @phone == "full_screen" && "px-page",
          @phone != "full_screen" && "px-cluster",
          footer[:class]
        ]}
      >
        {render_slot(footer)}
      </footer>

      <button
        id={"#{@id}-close-button"}
        type="button"
        data-modal-close
        data-slot="modal-close"
        aria-label={dgettext("default", "Close")}
        class="absolute top-group right-group inline-flex size-control-sm items-center justify-center rounded-control border border-transparent text-text-muted transition-colors outline-none hover:bg-surface-hover hover:text-text focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-focus-ring [&_svg]:size-icon-sm"
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
          this.opener = document.activeElement;
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

          // close() returns focus, but removing the open dialog drops it on the body
          if (!this.closed && document.activeElement === document.body && this.opener.isConnected) {
            this.opener.focus();
          }
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
