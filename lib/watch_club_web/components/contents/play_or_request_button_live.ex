defmodule WatchClubWeb.Components.Contents.PlayOrRequestButtonLive do
  @moduledoc """
  Loads the actor's `PlayOrRequestButton` for a Content, makes the request and gets the actor
  notified.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Contents.PlayOrRequestButton

  alias WatchClubWeb.Hooks.Flash

  @doc """
  The DOM id we recommend using for this Live Component
  Stable DOM id allows us to simplify PubSub notification handling. A page that shows the button
  twice for a Content gives the second one a `placement`.
  """
  def dom_id(identity, placement \\ nil)

  def dom_id(%ContentIdentity{} = identity, nil),
    do: "play-or-request-button-#{identity.external_id_source}-#{identity.external_id}"

  def dom_id(%ContentIdentity{} = identity, placement), do: "#{dom_id(identity)}-#{placement}"

  @doc """
  Updates the component when a relevant Ash Notification is received.
  We recommend using it on every LiveView that uses this LiveComponent for reactivity.
  This requires using dom_id() as the ID for the LiveComponent and the LiveView to have
  subscribed to the correct topics via `WatchClub.PubSub.subscribe_to_current_user_content_topics`.

  The button refreshes when Media have been added or removed from the Media center,
  when the Content Request for this content or the user's Request Subscriber of it has
  changed, or when the user's Watch Progress for this content has changed.
  """
  def handle_pubsub_message(notification, user, placements \\ [nil])

  def handle_pubsub_message(
        %Notification{
          resource: resource,
          metadata: %{content_identity: identity}
        },
        %User{} = user,
        placements
      )
      when resource in [ContentRequest, RequestSubscriber, Media, WatchProgress] do
    for placement <- placements do
      send_update(__MODULE__,
        id: dom_id(identity, placement),
        content_identity: identity,
        current_user: user
      )
    end
  end

  def handle_pubsub_message(_msg, _user, _placements), do: nil

  attr :content_identity, ContentIdentity, required: true
  attr :current_user, User, required: true
  attr :class, :any, default: nil
  attr :play_only, :boolean, default: false

  attr :on_episodes, :any,
    default: nil,
    doc:
      "the JS commands opening every TV Show Episode, from a caret joined to Play, or from Episodes when there's nothing to play"

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md"

  attr :variant, :string,
    values: ~w(button round),
    default: "button",
    doc: "round: only Play, with only its icon, over a poster"

  @impl true
  def render(assigns) do
    ~H"""
    <div class={@class}>
      <.play_or_request_button
        id={@id}
        has_media?={@has_media?}
        play_href={@play_href}
        play_label={@play_label}
        title={@title}
        request={@request}
        on_request={JS.push("request-content", target: @myself)}
        on_get_notified={JS.push("get-notified", target: @myself)}
        on_episodes={@on_episodes}
        play_only={@play_only}
        size={@size}
        variant={@variant}
      />
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
          :actor_progress_status,
          implementation: %{load: [tv_show: [actor_next_episode: [:actor_progress_status]]]},
          request: [:status, :download_progress, :actor_subscriber?, :requested_by]
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
        play_href: play_href((content && content.actor_next_medias_to_play) || []),
        play_label: play_label(assigns.content_identity.type, content),
        title: content && content.implementation.best_localization.title,
        request: content && content.request
      )
    end)
  end

  @impl true
  def handle_event("request-content", _params, socket) do
    case Requests.request_content(
           socket.assigns.content_identity,
           # For its title: the Content may not exist before its request
           load: [content: [:implementation]],
           actor: socket.assigns.current_user
         ) do
      {:ok, request} ->
        send_told_when_ready(request.content.implementation.best_localization.title)
        {:noreply, socket}

      {:error, _error} ->
        Flash.send_flash(:error, dgettext("contents", "Could not request this right now."))
        {:noreply, socket}
    end
  end

  def handle_event("get-notified", _params, socket) do
    Requests.get_notified!(socket.assigns.request.id, actor: socket.assigns.current_user)
    send_told_when_ready(socket.assigns.title)
    {:noreply, socket}
  end

  defp send_told_when_ready(title) do
    Flash.send_flash(
      :info,
      dgettext("contents", "You'll be told when %{title} is ready. It's in your Requests.",
        title: title
      )
    )
  end

  defp play_label(:movie, %Content{actor_progress_status: :in_progress}),
    do: dgettext("contents", "Resume")

  defp play_label(:movie, _content), do: dgettext("contents", "Play")
  defp play_label(:tv_show, nil), do: dgettext("contents", "Play %{episode}", episode: "S01E01")

  # No episode has aired yet
  defp play_label(:tv_show, %{implementation: %{actor_next_episode: nil}}),
    do: dgettext("contents", "Play")

  defp play_label(:tv_show, %{
         implementation: %{
           actor_next_episode: %TvShowEpisode{actor_progress_status: :in_progress} = episode
         }
       }),
       do:
         dgettext("contents", "Resume %{episode}", episode: "#{episode.formatted_episode_number}")

  defp play_label(:tv_show, %{implementation: %{actor_next_episode: episode}}),
    do: dgettext("contents", "Play %{episode}", episode: "#{episode.formatted_episode_number}")

  defp play_href([]), do: nil
  defp play_href(medias), do: Url.player_link(medias)
end
