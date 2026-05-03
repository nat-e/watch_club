defmodule WatchClubWeb.Modals.ViewInvitationLink do
  use WatchClubWeb, :live_component

  @modal_name "view_invitation_link"
  def modal_name, do: @modal_name

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.dialog>
        <:title>Invitation created</:title>
        <:description>
          Copy and share the invitation link below with anyone. It is only usable once.
        </:description>
        <div class="flex flex-col gap-4 items-center">
          <.alert class="items-center">
            <span id="invitation_link">{@invitation_link}</span>
            <:action>
              <.button
                phx-target={@myself}
                phx-click={
                  JS.dispatch("wc:copy_to_clipboard", to: "#invitation_link")
                  |> JS.push("link_copied")
                }
              >
                <Lucideicons.copy />
              </.button>
            </:action>
          </.alert>
          <.button phx-target={@myself} type="button" class="w-full" phx-click="close">
            Close
          </.button>
        </div>
      </.dialog>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("close", _params, socket) do
    send(self(), {:close_modal, @modal_name, []})
    {:noreply, socket |> push_patch(to: "/")}
  end

  def handle_event("link_copied", _params, socket) do
    send(self(), {:put_flash, :info, "Invitation link copied"})
    {:noreply, socket}
  end
end
