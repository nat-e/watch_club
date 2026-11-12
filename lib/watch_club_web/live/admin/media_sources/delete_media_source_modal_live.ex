defmodule WatchClubWeb.Admin.MediaSources.DeleteMediaSourceModalLive do
  @moduledoc """
  Confirm modal for deleting a `Media Source` and its `Media`. Their files stay on disk.

  The delete runs in the background, because a Media Source with many Media can take longer than
  LiveView waits for an event's reply. Closing the modal hides it, and the delete still finishes.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Media.SourceIdentifier

  alias WatchClubWeb.Hooks.Flash

  @impl true
  def mount(socket), do: {:ok, assign(socket, :deleting?, false)}

  attr :id, :string, required: true
  attr :media_source, Source, required: true
  attr :current_user, User, required: true
  attr :on_close, :any, required: true, doc: "a function the dialog calls once it closes"

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.modal id="delete-media-source-modal" size="sm" on_close={JS.push("close", target: @myself)}>
        <:title>{dgettext("admin_media_imports", "Delete Media Source")}</:title>
        <.stack space="related">
          <p class="text-sm text-text">
            {raw(
              dgettext("admin_media_imports", "This will delete the Media Source %{name}:",
                name: gtbold(@media_source.name)
              )
            )}
          </p>
          <.source_identifier media_source={@media_source} />
          <p class="text-sm text-text-muted">
            {dgettext(
              "admin_media_imports",
              "Its media will be removed from the instance too. Their files stay on disk."
            )}
          </p>
        </.stack>

        <:footer>
          <.button
            id="cancel-delete-media-source-button"
            type="button"
            variant="secondary"
            disabled={@deleting?}
            data-modal-close
          >
            {dgettext("default", "Cancel")}
          </.button>
          <.button
            id="confirm-delete-media-source-button"
            variant="danger"
            disabled={@deleting?}
            phx-click="delete"
            phx-target={@myself}
          >
            <:icon :if={@deleting?} position="start">
              <Lucideicons.loader_circle class="motion-safe:animate-spin" />
            </:icon>
            {if @deleting?,
              do: dgettext("admin_media_imports", "Deleting…"),
              else: dgettext("admin_media_imports", "Delete Media Source")}
          </.button>
        </:footer>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("delete", _params, socket) do
    %{media_source: media_source, current_user: user} = socket.assigns
    otel_context = OpenTelemetry.Ctx.get_current()

    {:noreply,
     socket
     |> assign(:deleting?, true)
     |> start_async(:delete, fn ->
       OpenTelemetry.Ctx.attach(otel_context)
       MediaSources.destroy_media_source!(media_source, actor: user)
     end)}
  end

  def handle_event("close", _params, socket) do
    socket.assigns.on_close.()
    {:noreply, socket}
  end

  @impl true
  def handle_async(:delete, {:ok, :ok}, socket) do
    Flash.send_flash(:info, dgettext("admin_media_imports", "Media Source deleted"))
    socket.assigns.on_close.()
    {:noreply, socket}
  end
end
