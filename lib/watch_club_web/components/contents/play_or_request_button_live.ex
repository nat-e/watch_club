defmodule WatchClubWeb.Components.Contents.PlayOrRequestButtonLive do
  @moduledoc """
  Loads the actor's `PlayOrRequestButton` for a Content. Its Request does Request Content, or
  Get Notified once somebody else made the Content Request.
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
  attr :on_tv?, :boolean, default: false, doc: "whether Play plays on the User's TV"
  attr :class, :any, default: nil

  attr :on_episodes, :any,
    default: nil,
    doc:
      "the JS commands opening every TV Show Episode, from a caret joined to Play while it's enabled"

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md",
    doc: "the button variant's"

  attr :variant, :string,
    values: ~w(button round poster),
    default: "button",
    doc:
      "round: a 40px circle with only an icon, or a ring for the request's status. poster: the same at 48px, with a shadow, over a poster."

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
        on_request={JS.push("request", target: @myself)}
        release_date={@release_date}
        locale={@current_user.settings.locale}
        on_episodes={@on_episodes}
        focus_status={@focus_status}
        size={@size}
        variant={@variant}
      />
    </div>
    """
  end

  @impl true
  def mount(socket), do: {:ok, assign(socket, :focus_status, false)}

  @impl true
  def update_many(assigns_sockets) do
    identities = Enum.map(assigns_sockets, fn {assigns, _socket} -> assigns.content_identity end)

    actor = assigns_sockets |> List.first() |> Kernel.elem(0) |> Map.fetch!(:current_user)

    contents_by_identity =
      Contents.get_contents_by_identities!(identities,
        load: [
          :has_media?,
          :title,
          :actor_next_medias_to_play,
          :actor_progress_status,
          implementation: %{load: [tv_show: [actor_next_episode: [:actor_progress_status]]]},
          request: [:status, :download_progress, :actor_subscriber?]
        ],
        actor: actor
      )
      |> Map.new(&{ContentIdentity.from_content(&1), &1})

    assigns_sockets
    |> Enum.map(fn {assigns, socket} ->
      content = Map.get(contents_by_identity, assigns.content_identity)

      socket = assign(socket, assigns)

      socket
      |> assign(
        has_media?: (content && content.has_media?) || false,
        play_href: play_href((content && content.actor_next_medias_to_play) || []),
        play_label:
          play_label(assigns.content_identity.type, content, socket.assigns[:on_tv?] || false),
        title: content && content.title,
        request: content && content.request,
        release_date: content && content.release_date
      )
    end)
  end

  @impl true
  def handle_event("request", _params, %{assigns: %{request: nil}} = socket) do
    case Requests.request_content(
           socket.assigns.content_identity,
           # For its title: the Content may not exist before its request
           load: [content: [:title]],
           actor: socket.assigns.current_user
         ) do
      {:ok, request} ->
        send_told_when_ready(request.content.title)
        {:noreply, assign(socket, :focus_status, true)}

      {:error, _error} ->
        Flash.send_flash(:error, dgettext("contents", "Could not request this right now."))
        {:noreply, socket}
    end
  end

  # Somebody else requested it
  def handle_event("request", _params, socket) do
    Requests.get_notified!(socket.assigns.request.id, actor: socket.assigns.current_user)
    send_told_when_ready(socket.assigns.title)
    {:noreply, assign(socket, :focus_status, true)}
  end

  defp send_told_when_ready(title) do
    Flash.send_flash(
      :info,
      dgettext("contents", "You'll be told when %{title} is ready. It's in your Requests.",
        title: title
      )
    )
  end

  # A Movie or a Sports Event
  defp play_label(type, %Content{actor_progress_status: :in_progress}, false)
       when type in [:movie, :sports_event],
       do: dgettext("contents", "Resume")

  defp play_label(type, %Content{actor_progress_status: :in_progress}, true)
       when type in [:movie, :sports_event],
       do: dgettext("contents", "Resume on TV")

  defp play_label(type, _content, false) when type in [:movie, :sports_event],
    do: dgettext("contents", "Play")

  defp play_label(type, _content, true) when type in [:movie, :sports_event],
    do: dgettext("contents", "Play on TV")

  defp play_label(:tv_show, nil, on_tv?), do: play_episode_label("S01E01", on_tv?)

  # No episode has aired yet
  defp play_label(:tv_show, %{implementation: %{actor_next_episode: nil}}, _on_tv?),
    do: dgettext("contents", "Play")

  defp play_label(
         :tv_show,
         %{
           implementation: %{
             actor_next_episode: %TvShowEpisode{actor_progress_status: :in_progress} = episode
           }
         },
         false
       ),
       do: dgettext("contents", "Resume %{episode}", episode: episode.formatted_episode_number)

  defp play_label(
         :tv_show,
         %{
           implementation: %{
             actor_next_episode: %TvShowEpisode{actor_progress_status: :in_progress} = episode
           }
         },
         true
       ),
       do:
         dgettext("contents", "Resume %{episode} on TV",
           episode: episode.formatted_episode_number
         )

  defp play_label(:tv_show, %{implementation: %{actor_next_episode: episode}}, on_tv?),
    do: play_episode_label(episode.formatted_episode_number, on_tv?)

  defp play_episode_label(episode, false),
    do: dgettext("contents", "Play %{episode}", episode: episode)

  defp play_episode_label(episode, true),
    do: dgettext("contents", "Play %{episode} on TV", episode: episode)

  defp play_href([]), do: nil
  defp play_href(medias), do: Url.player_link(medias)
end
