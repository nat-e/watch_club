defmodule WatchClubWeb.MyRequestsPage do
  @moduledoc """
  My Requests: the Content Requests the User is a Request Subscriber of. The playable ones come
  first, as a row of Browse's posters, the most recently playable first. The ready unseen ones
  lead the row, ringed, with a New badge, until the User leaves the page, since opening it marks
  them seen. The others follow as a list, the most recently changed first when the page opens,
  each saying when it can be watched.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.PosterCard
  import WatchClubWeb.MyRequestsPage.RequestOnTheWay

  alias WatchClub.Conversations.Participant
  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive

  @request_fields_to_load [
    :ready?,
    :ready_unseen_for_actor?,
    :status,
    :download_progress,
    content: [:implementation, :actor_progress_status, actor_recommendations: [:recommended_by]]
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      title={dgettext("requests", "My Requests")}
      space="section"
      class="@container"
    >
      <%!-- Hidden while the stream is empty --%>
      <.page_section
        id="ready-requests-heading"
        title={dgettext("requests", "Ready to watch")}
        class="peer not-has-[[data-ready-request]]:hidden"
      >
        <.scroll_row id="ready-requests" stream>
          <div
            :for={{dom_id, request} <- @streams.ready_requests}
            id={dom_id}
            data-ready-request
            class="w-28 shrink-0 snap-start @3xl:w-36"
          >
            <.poster_card
              content={request.content}
              locale={@current_user.settings.locale}
              ready_unseen={request.id in @ready_unseen_ids}
            >
              <:action>
                <.live_component
                  id={PlayOrRequestButtonLive.dom_id(ContentIdentity.from_content(request.content))}
                  module={PlayOrRequestButtonLive}
                  content_identity={ContentIdentity.from_content(request.content)}
                  current_user={@current_user}
                  variant="round"
                  size="lg"
                />
              </:action>
            </.poster_card>
          </div>
        </.scroll_row>
      </.page_section>

      <.page_section
        :if={@requests_on_the_way != []}
        id="requests-on-the-way-heading"
        title={dgettext("requests", "On the way")}
        class="max-w-readable"
      >
        <.stack as="ul" space="cluster">
          <.request_on_the_way
            :for={{request, index} <- Enum.with_index(@requests_on_the_way)}
            request={request}
            focus_after_removal={focus_after_removal(@requests_on_the_way, index)}
            locale={@current_user.settings.locale}
          />
        </.stack>
      </.page_section>

      <%!-- Shown when the Ready section, its peer before it, is hidden too --%>
      <.empty
        :if={@requests_on_the_way == []}
        id="my-requests-empty"
        class="peer-has-[[data-ready-request]]:hidden"
      >
        <:icon><Lucideicons.download /></:icon>
        <:title>{dgettext("requests", "No requests yet")}</:title>
        <:description>
          {dgettext(
            "requests",
            "Search for a title in Browse and request it. You'll see here when you can watch it."
          )}
        </:description>
        <.button id="my-requests-browse" variant="secondary" navigate={~p"/"}>
          <:icon><Lucideicons.clapperboard /></:icon>
          {dgettext("nav", "Browse")}
        </.button>
      </.empty>
    </Layouts.app>
    """
  end

  # The previous row's button, or the heading for the first row. Not the next row's: the rows
  # after the removed one move in the page, which drops their focus.
  defp focus_after_removal(_requests, 0), do: "requests-on-the-way-heading"

  defp focus_after_removal(requests, index),
    do: "stop-getting-notified-#{Enum.at(requests, index - 1).id}"

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    socket = WatchClub.PubSub.subscribe_to_current_user_content_topics(socket)

    ready_requests =
      Requests.list_current_user_ready_requests!(load: @request_fields_to_load, actor: user)

    # Intentionally small: the ones that just became playable
    ready_unseen_ids =
      for %{ready_unseen_for_actor?: true} = request <- ready_requests,
          into: MapSet.new(),
          do: request.id

    # Only now that the list says which to ring
    if connected?(socket), do: Requests.mark_current_user_requests_seen!(actor: user)

    {:ok,
     socket
     |> assign(:ready_unseen_ids, ready_unseen_ids)
     |> stream_configure(:ready_requests, dom_id: &"ready-request-#{&1.content_id}")
     |> stream(:ready_requests, ready_requests)
     # Intentionally small: what's still downloading or waiting to be
     |> assign(
       :requests_on_the_way,
       Requests.list_current_user_requests_on_the_way!(
         load: @request_fields_to_load,
         actor: user
       )
     )}
  end

  @impl true
  def handle_event("stop-getting-notified", %{"id" => id}, socket) do
    Requests.stop_getting_notified!(id, actor: socket.assigns.current_user)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Notification{} = notification, socket) do
    # Updates the posters' Play buttons
    PlayOrRequestButtonLive.handle_pubsub_message(notification, socket.assigns.current_user)

    # A Content Request, the User's subscription to it, its Content, the User's Watch Progress on
    # it, or a recommendation of it changed. Every User gets the notifications of every Content
    # Request and Content, so this queries for each: fine with the few Users of an instance.
    case notification do
      %{resource: resource, metadata: %{content_id: content_id}}
      when resource in [ContentRequest, RequestSubscriber, WatchProgress] ->
        {:noreply, sync_request(socket, content_id)}

      %{resource: Participant, action: %{name: :create}, metadata: %{content_id: content_id}} ->
        {:noreply, sync_request(socket, content_id)}

      %{resource: Content, data: %Content{id: content_id}} ->
        {:noreply, sync_request(socket, content_id)}

      _other ->
        {:noreply, socket}
    end
  end

  # Shows it where it belongs now, or removes it
  defp sync_request(socket, content_id) do
    case Requests.get_current_user_request_for_content(content_id,
           load: @request_fields_to_load,
           actor: socket.assigns.current_user
         ) do
      {:ok, %ContentRequest{ready?: true} = request} ->
        socket |> remove_request_on_the_way(content_id) |> show_ready_request(request)

      {:ok, %ContentRequest{ready?: false} = request} ->
        socket |> stream_delete(:ready_requests, request) |> show_request_on_the_way(request)

      # Deleted, or the User stopped getting notified, or a Content without a Content Request
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} ->
        socket
        |> stream_delete(:ready_requests, %ContentRequest{content_id: content_id})
        |> remove_request_on_the_way(content_id)
    end
  end

  # One that became playable while the User is on the page is seen at once, and leads the row.
  # The others update in place.
  defp show_ready_request(socket, %ContentRequest{ready_unseen_for_actor?: true} = request) do
    Requests.mark_current_user_requests_seen!(actor: socket.assigns.current_user)

    socket
    |> update(:ready_unseen_ids, &MapSet.put(&1, request.id))
    |> stream_insert(:ready_requests, request, at: 0)
  end

  defp show_ready_request(socket, request),
    do: stream_insert(socket, :ready_requests, request, at: 0)

  defp remove_request_on_the_way(socket, content_id),
    do:
      update(
        socket,
        :requests_on_the_way,
        &Enum.reject(&1, fn request -> request.content_id == content_id end)
      )

  # While the User is on the page, one that changes keeps its place, so the rows don't move under
  # them, and one new to the list leads it
  defp show_request_on_the_way(socket, %ContentRequest{id: id} = request) do
    update(socket, :requests_on_the_way, fn requests ->
      if Enum.any?(requests, &(&1.id == id)),
        do: Enum.map(requests, &if(&1.id == id, do: request, else: &1)),
        else: [request | requests]
    end)
  end
end
