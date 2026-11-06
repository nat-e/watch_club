defmodule WatchClubWeb.MyRequestsPage do
  @moduledoc """
  My Requests: the Content Requests the User is a Request Subscriber of. The playable ones come
  first, as a row of Browse's posters. The ready unseen ones lead the row, ringed, with a New
  badge, until the User leaves the page, since opening it marks them seen. The others follow as
  a list, soonest first, each saying when it can be watched.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClubWeb.Components.Contents.{PlayOrRequestButtonLive, PosterCard}

  @request_fields_to_load [
    :ready?,
    :ready_unseen_for_actor?,
    :status,
    :download_progress,
    content: [:implementation, :actor_progress_status]
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
      <section
        aria-labelledby="ready-requests-heading"
        class="peer flex min-w-0 flex-col gap-group not-has-[[data-ready-request]]:hidden"
      >
        <h2 id="ready-requests-heading" class="font-heading text-xl font-semibold">
          {dgettext("requests", "Ready to watch")}
        </h2>
        <.scroll_row id="ready-requests" stream>
          <div
            :for={{dom_id, request} <- @streams.ready_requests}
            id={dom_id}
            data-ready-request
            class="w-28 shrink-0 snap-start @3xl:w-36"
          >
            <PosterCard.poster_card
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
                />
              </:action>
            </PosterCard.poster_card>
          </div>
        </.scroll_row>
      </section>

      <section
        :if={@requests_on_the_way != []}
        aria-labelledby="requests-on-the-way-heading"
        class="flex min-w-0 max-w-readable flex-col gap-related"
      >
        <h2 id="requests-on-the-way-heading" class="font-heading text-xl font-semibold">
          {dgettext("requests", "On the way")}
        </h2>
        <ul class="flex flex-col">
          <.request_on_the_way
            :for={request <- @requests_on_the_way}
            request={request}
            locale={@current_user.settings.locale}
          />
        </ul>
      </section>

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

  attr :request, ContentRequest, required: true
  attr :locale, :atom, required: true

  # Its poster and its name, which open its Content, and when it can be watched
  defp request_on_the_way(assigns) do
    assigns =
      assigns
      |> assign(:title, assigns.request.content.implementation.best_localization.title)
      |> assign(
        :path,
        Url.content_details_link(ContentIdentity.from_content(assigns.request.content))
      )

    ~H"""
    <li id={"request-on-the-way-#{@request.id}"} class="flex items-center gap-group py-group">
      <%!-- Screen readers and keyboards reach the name's link --%>
      <.link navigate={@path} tabindex="-1" aria-hidden="true" class="shrink-0">
        <.tmdb_poster
          path={@request.content.implementation.best_localization.poster_path}
          size="w154"
          class="w-20"
        />
      </.link>
      <div class="flex min-w-0 flex-1 flex-col">
        <.link navigate={@path} class="truncate text-lg font-semibold hover:underline">
          {@title}
        </.link>
        <span class="flex gap-tight text-sm text-text-muted">
          <span class="flex h-lh shrink-0 items-center">
            <.status_icon status={@request.status} />
          </span>
          {when_watchable(@request, @locale)}
        </span>
        <.progress_bar
          :if={@request.status == :downloading}
          percent={@request.download_progress}
          class="mt-related max-w-48"
        />
      </div>
      <.button
        id={"stop-getting-notified-#{@request.id}"}
        variant="ghost"
        size="icon-sm"
        aria-label={dgettext("requests", "Stop getting notified about %{title}", title: @title)}
        title={dgettext("requests", "Stop getting notified")}
        phx-click="stop-getting-notified"
        phx-value-id={@request.id}
      >
        <Lucideicons.x />
      </.button>
    </li>
    """
  end

  attr :status, :atom, required: true, doc: "a `ContentRequestStatus`"

  defp status_icon(assigns) do
    ~H"""
    <Lucideicons.download
      :if={@status in [:importing, :downloading]}
      class="size-icon-sm shrink-0 text-accent"
    />
    <Lucideicons.clock :if={@status == :queued} class="size-icon-sm shrink-0 text-text-subtle" />
    <Lucideicons.calendar
      :if={@status == :not_released}
      class="size-icon-sm shrink-0 text-text-subtle"
    />
    <Lucideicons.search_x :if={@status == :not_found} class="size-icon-sm shrink-0 text-text-subtle" />
    <Lucideicons.circle_alert :if={@status == :failed} class="size-icon-sm shrink-0 text-danger" />
    """
  end

  defp when_watchable(%ContentRequest{status: :importing}, _locale),
    do: dgettext("requests", "Almost ready")

  defp when_watchable(%ContentRequest{status: :downloading} = request, _locale),
    do: dgettext("requests", "%{percent}% downloaded", percent: round(request.download_progress))

  defp when_watchable(%ContentRequest{status: :queued}, _locale),
    do: dgettext("requests", "Queued")

  # TMDB's date is often the cinema release, before the one we can download
  defp when_watchable(%ContentRequest{status: :not_released} = request, locale) do
    release_date = request.content.release_date

    if release_date && Date.after?(release_date, Date.utc_today()) do
      dgettext("requests", "Out on %{date}", date: Time.long_date(release_date, locale))
    else
      dgettext("requests", "Not released yet")
    end
  end

  defp when_watchable(%ContentRequest{status: :not_found}, _locale),
    do: dgettext("requests", "Not found, we'll keep looking for it")

  defp when_watchable(%ContentRequest{status: :failed}, _locale),
    do: dgettext("requests", "There was a problem, the instance administrator was told")

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    ready_requests =
      Requests.list_current_user_ready_requests!(load: @request_fields_to_load, actor: user)

    if connected?(socket), do: Requests.mark_current_user_requests_seen!(actor: user)

    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     # Intentionally small: the ones that just became playable
     |> assign(
       :ready_unseen_ids,
       for(
         %{ready_unseen_for_actor?: true} = request <- ready_requests,
         into: MapSet.new(),
         do: request.id
       )
     )
     |> stream_configure(:ready_requests, dom_id: &"ready-request-#{&1.content_id}")
     |> stream(:ready_requests, ready_requests)
     |> load_requests_on_the_way()}
  end

  @impl true
  def handle_event("stop-getting-notified", %{"id" => id}, socket) do
    case Requests.stop_getting_notified(id, actor: socket.assigns.current_user) do
      :ok -> {:noreply, socket}
      # Clicked again before its row went away
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} -> {:noreply, socket}
    end
  end

  @impl true
  # A Content Request, the User's subscription to it, or its Content changed. Every User gets
  # the notifications of every Content Request and Content, so this queries for each: fine with
  # the few Users of an instance.
  def handle_info(%Notification{resource: resource, metadata: %{content_id: content_id}}, socket)
      when resource in [ContentRequest, RequestSubscriber] do
    {:noreply, show_request(socket, content_id)}
  end

  def handle_info(%Notification{data: %Content{id: content_id}}, socket) do
    {:noreply, show_request(socket, content_id)}
  end

  def handle_info(message, socket) do
    # Send updates to all the Live Components we are using on the posters
    PlayOrRequestButtonLive.handle_pubsub_message(message, socket.assigns.current_user)

    {:noreply, socket}
  end

  defp show_request(socket, content_id) do
    case Requests.get_current_user_request_for_content(content_id,
           load: @request_fields_to_load,
           actor: socket.assigns.current_user
         ) do
      {:ok, %ContentRequest{ready?: true} = request} ->
        socket |> remove_request_on_the_way(content_id) |> show_ready_request(request)

      {:ok, %ContentRequest{ready?: false} = request} ->
        socket |> stream_delete(:ready_requests, request) |> load_requests_on_the_way()

      # Deleted, or the User stopped getting notified, or a Content without a Content Request
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} ->
        socket
        |> stream_delete_by_dom_id(:ready_requests, "ready-request-#{content_id}")
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

  defp load_requests_on_the_way(socket) do
    # Intentionally small: what's still downloading or waiting to be
    assign(
      socket,
      :requests_on_the_way,
      Requests.list_current_user_requests_on_the_way!(
        load: @request_fields_to_load,
        actor: socket.assigns.current_user
      )
    )
  end
end
