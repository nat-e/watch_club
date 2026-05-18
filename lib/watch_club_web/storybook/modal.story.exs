defmodule WatchClubWeb.Storybook.Modal do
  use PhoenixStorybook.Story, :example

  import WatchClubWeb.Components.UI.Alert
  import WatchClubWeb.Components.UI.Button
  import WatchClubWeb.Components.UI.Input
  import WatchClubWeb.Components.UI.Modal

  alias Phoenix.LiveView.JS

  def doc do
    "Interactive examples for the Watch Club modal component."
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, modal: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto grid max-w-5xl gap-8 p-6 text-text">
      <div class="grid gap-2">
        <p class="text-sm font-medium text-primary">Dialog / Modal</p>
        <h1 class="text-3xl font-semibold tracking-tight">Watch Club modals</h1>
        <p class="max-w-2xl text-text-muted">
          Modals combine the overlay shell, header, body, footer, and close behavior in a single
          component. They are rendered when open and use <code>on_close</code> to clear LiveView
          state after Escape, the close button, or a footer action closes the native dialog.
        </p>
      </div>

      <div class="grid gap-4 md:grid-cols-3">
        <.showcase_card
          modal="invite"
          title="Default"
          description="Title, description, body content, and footer actions."
          button_label="Open default modal"
        >
          Best for short forms and focused decisions.
        </.showcase_card>

        <.showcase_card
          modal="danger"
          title="Destructive"
          description="Confirmation copy paired with a danger action."
          button_label="Open danger modal"
        >
          Use for irreversible or high-risk actions.
        </.showcase_card>

        <.showcase_card
          modal="scrollable"
          title="Scrollable"
          description="Long content stays inside the overlay bounds."
          button_label="Open scrollable modal"
        >
          Useful when details need to stay in context.
        </.showcase_card>
      </div>

      <.invite_modal :if={@modal == :invite} />
      <.danger_modal :if={@modal == :danger} />
      <.scrollable_modal :if={@modal == :scrollable} />
    </div>
    """
  end

  @impl true
  def handle_event("open_modal", %{"modal" => modal}, socket) do
    {:noreply, assign(socket, modal: modal_name(modal))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil)}
  end

  attr :modal, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :button_label, :string, required: true
  slot :inner_block, required: true

  defp showcase_card(assigns) do
    ~H"""
    <section class="grid gap-4 rounded-card border border-border bg-surface p-5 shadow-card">
      <div class="grid gap-2">
        <h2 class="text-xl font-semibold">{@title}</h2>
        <p class="text-sm text-text-muted">{@description}</p>
      </div>
      <div class="rounded-control border border-border-subtle bg-surface-inset p-3 text-sm text-text-muted">
        {render_slot(@inner_block)}
      </div>
      <.button variant="secondary" phx-click="open_modal" phx-value-modal={@modal}>
        {@button_label}
      </.button>
    </section>
    """
  end

  defp invite_modal(assigns) do
    ~H"""
    <.modal id="storybook-invite-modal" on_close={close_modal()}>
      <:title>Invite a member</:title>
      <:description>Create a one-time invitation link for a trusted friend.</:description>

      <div class="grid gap-4">
        <label class="grid gap-2">
          <span class="text-sm font-medium text-text">Email address</span>
          <.input
            id="storybook-invite-email"
            name="email"
            type="email"
            placeholder="friend@example.com"
          />
        </label>
        <p class="text-sm text-text-muted">
          Invitation links can only be used once and inherit the selected club role.
        </p>
      </div>

      <:footer>
        <.button type="button" variant="secondary" data-modal-close>Cancel</.button>
        <.button type="button">Create invitation</.button>
      </:footer>
    </.modal>
    """
  end

  defp danger_modal(assigns) do
    ~H"""
    <.modal id="storybook-danger-modal" on_close={close_modal()}>
      <:title>Delete library?</:title>
      <:description>This action removes the library from the club.</:description>

      <.alert variant="danger">
        <:title>Deletion cannot be undone from this screen.</:title>
        The underlying content records are kept, but members will lose access to this library.
      </.alert>

      <:footer>
        <.button type="button" variant="secondary" data-modal-close>Cancel</.button>
        <.button type="button" variant="danger">Delete library</.button>
      </:footer>
    </.modal>
    """
  end

  defp scrollable_modal(assigns) do
    ~H"""
    <.modal id="storybook-scrollable-modal" on_close={close_modal()}>
      <:title>Club guidelines</:title>
      <:description>Long content scrolls within the modal panel.</:description>

      <div class="grid gap-4">
        <p :for={section <- 1..8}>
          Guideline {section}: keep recommendations thoughtful, spoiler-free, and useful for the
          rest of the club. Add context about why the movie, show, or book belongs in the library.
        </p>
      </div>

      <:footer>
        <.button type="button" data-modal-close>Got it</.button>
      </:footer>
    </.modal>
    """
  end

  defp close_modal, do: JS.push("close_modal")

  defp modal_name("invite"), do: :invite
  defp modal_name("danger"), do: :danger
  defp modal_name("scrollable"), do: :scrollable
  defp modal_name(_unknown), do: nil
end
