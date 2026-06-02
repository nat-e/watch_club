defmodule WatchClubWeb.MyRequestsPage do
  use WatchClubWeb, :live_view

  alias Ash.Notifier.Notification
  alias WatchClub.Contents.ContentType
  alias WatchClub.Requests
  alias WatchClub.Requests.ContentRequest
  alias WatchClub.Requests.ContentRequestSort
  alias WatchClub.Requests.ContentRequestStatusGroup
  alias WatchClubWeb.Components.Requests.RequestCard
  alias WatchClubWeb.Helpers.KeysetStreamState
  import WatchClubWeb.Components.Settings.SettingsHeader

  @page_size 25

  # Filters are carried as atoms: an enum value, or `nil` for "no filter" (the
  # "All" chip). `Url.parse_url_param/3` validates the raw param against each
  # domain module's `values/0`; `nil` flows straight through to the URL (dropped
  # by `path/1`), the action filters (`maybe_filter/3`), and `matches_filters?/2`.
  # The status_group → status collapsing happens server-side, in `for_current_user`.

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # One topic carries everything for this user's requests: create/cancel
    # (ContentRequest `pub_sub`) and status/progress moves fanned out from
    # Media Source Request writes (see MediaSourceRequest's NotifyRequesters).
    if connected?(socket) do
      Phoenix.PubSub.subscribe(WatchClub.PubSub, "content_requests:user:#{user.id}")
    end

    {:ok,
     socket
     |> stream_configure(:requests, dom_id: &"request-#{&1.id}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    stream_state = KeysetStreamState.init(@page_size)

    {:noreply,
     socket
     |> assign(
       :sort,
       Url.parse_url_param(
         params["sort"],
         ContentRequestSort.values(),
         ContentRequestSort.default()
       )
     )
     |> assign(
       :status_filter,
       Url.parse_url_param(params["status"], ContentRequestStatusGroup.values())
     )
     |> assign(:content_type_filter, Url.parse_url_param(params["type"], ContentType.values()))
     |> assign(:stream_state, stream_state)
     |> load_requests_page(stream_state)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    stream_state = socket.assigns.stream_state

    if KeysetStreamState.can_load_more?(stream_state) do
      {:noreply, socket |> load_requests_page(stream_state)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel-request", %{"id" => id}, socket) do
    Requests.cancel_content_request(id, actor: socket.assigns.current_user)
    {:noreply, socket}
  end

  # The user created (or re-requested) content, here or in another tab. Prepend
  # the new card (most-recent-activity sort) if it matches the active filters;
  # ignore it otherwise.
  @impl true
  def handle_info(
        %Notification{
          resource: ContentRequest,
          action: %{name: :request},
          data: %{id: request_id}
        },
        socket
      ) do
    socket =
      case fetch_request(socket, request_id) do
        {:ok, %ContentRequest{} = request} ->
          if matches_filters?(request, socket),
            do: stream_insert(socket, :requests, request, at: 0),
            else: socket

        _ ->
          socket
      end

    {:noreply, socket}
  end

  # The user cancelled a request, here or in another tab. Drop the card (a
  # no-op if it isn't loaded — e.g. this tab already removed it).
  def handle_info(
        %Notification{resource: ContentRequest, action: %{type: :destroy}, data: %{id: id}},
        socket
      ) do
    {:noreply, stream_delete(socket, :requests, %{id: id})}
  end

  # A Media Source Request write fanned out to us (see NotifyRequesters): this
  # user's *derived* status/progress for that content may have moved. Re-read
  # the one card and patch it in place when it still matches (no `:at`, so it
  # keeps its position), or drop it when the change pushed it out of the filter.
  # `update_only` leaves an unloaded-but-matching request for the next load
  # rather than inserting it out of sort order.
  def handle_info({:request_changed, id}, socket) do
    socket =
      case fetch_request(socket, id) do
        {:ok, %ContentRequest{} = request} ->
          if matches_filters?(request, socket),
            do: stream_insert(socket, :requests, request, update_only: true),
            else: stream_delete(socket, :requests, request)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      class="max-w-layout-page"
    >
      <.settings_header title="My Requests" description="" />

      <.cluster space="tight" aria-label="Filter by status" class="mb-related">
        <.status_chip
          :for={group <- [nil | ContentRequestStatusGroup.values()]}
          group={group}
          current={@status_filter}
          sort={@sort}
          type={@content_type_filter}
        />
      </.cluster>

      <div class="mb-cluster flex flex-wrap items-center justify-between gap-related">
        <nav aria-label="Filter by content type" class="flex items-center gap-cluster">
          <.content_type_filter
            :for={type <- [nil | ContentType.library_display_order()]}
            type={type}
            current={@content_type_filter}
            sort={@sort}
            status={@status_filter}
          />
        </nav>

        <.dropdown_menu id="my-requests-sort">
          <:trigger>
            <.button id="my-requests-sort-trigger" variant="ghost">
              <:icon><Lucideicons.arrow_up_down /></:icon>
              Sort: {ContentRequestSort.translated_label(@sort)}
              <:icon position="end"><Lucideicons.chevron_down /></:icon>
            </.button>
          </:trigger>
          <.dropdown_menu_item
            :for={sort <- ContentRequestSort.values()}
            id={"my-requests-sort-#{sort}"}
            patch={path(status: @status_filter, type: @content_type_filter, sort: sort)}
          >
            <Lucideicons.check class={if @sort == sort, do: "", else: "invisible"} />
            {ContentRequestSort.translated_label(sort)}
          </.dropdown_menu_item>
        </.dropdown_menu>
      </div>

      <.stack id="my-requests" class="@container" phx-update="stream" space="related">
        <div
          id="my-requests-empty"
          class="only:block hidden"
        >
          <.empty size="sm">
            <:icon><Lucideicons.inbox /></:icon>
            <:title>No requests match</:title>
            <:description>
              Try clearing some filters, or browse content to add a request.
            </:description>
          </.empty>
        </div>

        <RequestCard.request_card
          :for={{dom_id, request} <- @streams.requests}
          id={dom_id}
          request={request}
          current_user={@current_user}
        />
      </.stack>

      <.infinite_scroll_trigger
        :if={KeysetStreamState.can_load_more?(@stream_state)}
        id="my-requests-load-more"
        event="load_more"
      />
    </Layouts.app>
    """
  end

  attr :group, :atom
  attr :current, :atom, required: true
  attr :sort, :atom, required: true
  attr :type, :atom, required: true

  defp status_chip(assigns) do
    ~H"""
    <.link
      patch={path(sort: @sort, type: @type, status: @group)}
      class={[
        "inline-flex items-center gap-tight rounded-full border px-related py-tight text-sm transition-colors",
        @current == @group && "border-border bg-surface-selected text-text",
        @current != @group &&
          "border-border-subtle bg-surface-inset text-text-muted hover:border-border hover:text-text"
      ]}
    >
      <span
        :if={@group != nil}
        class={[
          "inline-block size-2 shrink-0 rounded-full",
          @group == :in_progress && "bg-accent",
          @group == :completed && "bg-success",
          @group == :failed && "bg-danger",
          @group == :not_released && "bg-text-subtle"
        ]}
        aria-hidden="true"
      >
      </span>
      {ContentRequestStatusGroup.translated_label(@group)}
    </.link>
    """
  end

  attr :type, :atom, required: true
  attr :current, :atom, required: true
  attr :sort, :atom, required: true
  attr :status, :atom, required: true

  defp content_type_filter(assigns) do
    ~H"""
    <.link
      patch={path(sort: @sort, status: @status, type: @type)}
      class={[
        "border-b-2 pb-tight transition-colors",
        @current == @type && "border-accent text-text",
        @current != @type && "border-transparent text-text-muted hover:text-text"
      ]}
    >
      {ContentType.translated_plural_label(@type)}
    </.link>
    """
  end

  defp load_requests_page(socket, %KeysetStreamState{} = stream_state) do
    load =
      KeysetStreamState.load_page(
        stream_state,
        fn page_options ->
          Requests.list_content_requests_for_current_user(
            %{
              sort: socket.assigns.sort,
              status_group: socket.assigns.status_filter,
              content_type: socket.assigns.content_type_filter
            },
            actor: socket.assigns.current_user,
            page: page_options
          )
        end
      )

    case load do
      {:ok, new_state, results} ->
        socket
        |> assign(:stream_state, new_state)
        |> stream(:requests, results, reset: stream_state.status == :init)

      {:error, new_state, _} ->
        socket
        |> assign(:stream_state, new_state)
        |> put_flash(:error, "There was an error loading requests")
    end
  end

  # Re-read one of the user's requests by id with the card's view data — the
  # same load the list uses, plus `:status_group` for `matches_filters?/2`. The
  # `:read` policy scopes it to the actor, so a foreign id resolves to nothing.
  defp fetch_request(socket, request_id) do
    Requests.get_content_request_by_id(request_id, actor: socket.assigns.current_user)
  end

  defp matches_filters?(request, socket) do
    status_filter = socket.assigns.status_filter
    type_filter = socket.assigns.content_type_filter

    (status_filter == nil or request.status_group == status_filter) and
      (type_filter == nil or request.content.type == type_filter)
  end

  defp path(opts) do
    params =
      %{
        sort: Keyword.get(opts, :sort),
        status: Keyword.get(opts, :status),
        type: Keyword.get(opts, :type)
      }
      |> Map.reject(fn {_key, value} -> value == nil end)

    ~p"/my-requests?#{params}"
  end
end
