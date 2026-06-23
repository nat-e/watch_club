defmodule WatchClubWeb.Components.Contents.PlayOrRequestButtonLive do
  use WatchClubWeb, :live_component

  @doc """
  The DOM id we recommend using for this Live Component
  Stable DOM id allows us to simplify PubSub notification handling
  """
  def dom_id(%ContentIdentity{} = identity),
    do: "play-or-request-button-#{identity.external_id_source}-#{identity.external_id}"

  @doc """
  Updates the component when a relevant Ash Notification is received.
  We recommend using it on every LiveView that uses this LiveComponent for reactivity.
  This requires using dom_id() as the ID for the LiveComponent and the LiveView to have
  subscribed to the correct topics via `WatchClub.PubSub.subscribe_to_current_user_content_topics`.

  The button refreshes when Media have been added or removed from the Media center, or
  when the Content Request of the user for this content has changed.
  """
  def handle_pubsub_message(
        %Ash.Notifier.Notification{
          resource: resource,
          metadata: %{content_identity: identity}
        },
        %User{} = user
      )
      when resource in [ContentRequest, Media] do
    send_update(__MODULE__,
      id: dom_id(identity),
      content_identity: identity,
      current_user: user
    )
  end

  def handle_pubsub_message(_msg, _user), do: nil

  attr :content_identity, ContentIdentity, required: true
  attr :current_user, User, required: true
  attr :class, :any, default: nil

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md"

  @impl true
  def render(%{has_media?: false} = assigns) do
    ~H"""
    <div class={@class}>
      <.button
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
    </div>
    """
  end

  def render(%{has_media?: true, next_medias_to_play: []} = assigns) do
    ~H"""
    <div class={@class}>
      <.button
        id={"#{@id}-play-button"}
        size={@size}
        variant="primary"
        emphasis
        disabled
        class="w-full"
      >
        <:icon><Lucideicons.play /></:icon>
        {@play_label}
      </.button>
    </div>
    """
  end

  def render(%{has_media?: true} = assigns) do
    ~H"""
    <div class={@class}>
      <.button
        id={"#{@id}-play-button"}
        size={@size}
        variant="primary"
        emphasis
        href={Url.player_link(@next_medias_to_play)}
        class="w-full"
      >
        <:icon><Lucideicons.play /></:icon>
        {@play_label}
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
          :has_media?,
          :actor_next_medias_to_play,
          tv_show: [:actor_next_episode],
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
        has_media?: (content && content.has_media?) || false,
        next_medias_to_play: (content && content.actor_next_medias_to_play) || [],
        play_label: play_label(assigns.content_identity.type, content),
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

  defp play_label(:movie, _content), do: dgettext("contents", "Play")
  defp play_label(:tv_show, nil), do: dgettext("contents", "Play %{episode}", episode: "S01E01")

  defp play_label(:tv_show, %{tv_show: %{actor_next_episode: episode}}),
    do: dgettext("contents", "Play %{episode}", episode: "#{episode.formatted_episode_number}")
end
