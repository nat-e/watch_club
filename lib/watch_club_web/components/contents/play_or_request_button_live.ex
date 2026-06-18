defmodule WatchClubWeb.Components.Contents.PlayOrRequestButtonLive do
  use WatchClubWeb, :live_component

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.ContentIdentity
  alias WatchClub.Requests
  alias WatchClub.Requests.{ContentRequest, ContentRequestStatus}
  alias WatchClub.Shared.Url

  attr :content_identity, ContentIdentity, required: true
  attr :current_user, User, required: true
  attr :class, :any, default: nil

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md"

  @impl true
  def render(assigns) do
    ~H"""
    <div class={@class}>
      <.button
        :if={!@playable?}
        id={"#{@id}-request-button"}
        size={@size}
        variant="primary"
        emphasis
        phx-click="request-content"
        phx-target={@myself}
        disabled={@request != nil}
        class="w-full"
      >
        <:icon :if={@request != nil}><Lucideicons.loader_circle class="animate-spin" /></:icon>
        <:icon :if={@request == nil}><Lucideicons.download /></:icon>
        {(@request && ContentRequestStatus.translated_label(@request.status)) ||
          dgettext("contents", "Request")}
      </.button>
      <.button
        :if={@playable?}
        id={"#{@id}-play-button"}
        size={@size}
        variant="primary"
        emphasis
        href={Url.player_link(@next_medias_to_play)}
        class="w-full"
      >
        <:icon><Lucideicons.play /></:icon>
        {dgettext("contents", "Play")}
      </.button>
    </div>
    """
  end

  @impl true
  def update_many(assigns_sockets) do
    identities = Enum.map(assigns_sockets, fn {assigns, _socket} -> assigns.content_identity end)

    actor = assigns_sockets |> List.first() |> Kernel.elem(0) |> Map.fetch!(:current_user)

    contents_by_identity =
      Contents.get_contents_by_identities!(identities,
        load: [
          :playable?,
          :actor_next_medias_to_play,
          actor_request: Ash.Query.for_read(ContentRequest, :with_status, %{}, actor: actor)
        ],
        actor: actor
      )
      |> Map.new(&{ContentIdentity.from_content(&1), &1})

    assigns_sockets
    |> Enum.map(fn {assigns, socket} ->
      content = Map.get(contents_by_identity, assigns.content_identity)

      socket
      |> assign(assigns)
      |> assign(
        playable?: (content && content.playable?) || false,
        next_medias_to_play: (content && content.actor_next_medias_to_play) || [],
        request: (content && content.actor_request) || nil
      )
    end)
  end

  @impl true
  def handle_event("request-content", _params, socket) do
    case Requests.request_content(
           socket.assigns.content_identity,
           actor: socket.assigns.current_user
         ) do
      {:ok, _request} ->
        {:noreply, put_flash(socket, :info, dgettext("contents", "Added to your requests."))}

      {:error, _error} ->
        {:noreply,
         put_flash(socket, :error, dgettext("contents", "Could not request this right now."))}
    end
  end
end
