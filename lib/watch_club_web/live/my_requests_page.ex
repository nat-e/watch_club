defmodule WatchClubWeb.MyRequestsPage do
  use WatchClubWeb, :live_view

  alias WatchClub.Requests.{ContentRequestSort, ContentRequestStatusGroup}

  alias WatchClubWeb.Components.Contents.{
    AddToLibraryModalLive,
    PlayOrRequestButtonLive
  }

  alias WatchClubWeb.Components.Requests.RequestCard
  alias WatchClubWeb.Helpers.KeysetStreamState

  @page_size 25

  @request_fields_to_load [
    :best_source_request,
    :status_group,
    :percent_imported,
    content: [:implementation]
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      class="max-w-layout-page"
      title={dgettext("requests", "My Requests")}
    >
      <.cluster
        space="tight"
        role="group"
        aria-label={dgettext("requests", "Filter by status")}
        class="mb-related"
      >
        <.status_chip
          :for={group <- [nil | ContentRequestStatusGroup.values()]}
          group={group}
          current={@status_filter}
          sort={@sort}
          type={@content_type_filter}
        />
      </.cluster>

      <div class="mb-cluster flex flex-wrap items-center justify-between gap-related">
        <nav
          aria-label={dgettext("requests", "Filter by content type")}
          class="flex items-center gap-cluster"
        >
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
            <.button id="my-requests-sort-button" variant="ghost">
              <:icon><Lucideicons.arrow_up_down /></:icon>
              {dgettext("requests", "Sort: %{sort}", sort: ContentRequestSort.translated_label(@sort))}
              <:icon position="end"><Lucideicons.chevron_down /></:icon>
            </.button>
          </:trigger>
          <.dropdown_menu_item
            :for={sort <- ContentRequestSort.values()}
            id={"my-requests-sort-#{sort}"}
            patch={path(status: @status_filter, type: @content_type_filter, sort: sort)}
            checked={@sort == sort}
          >
            {ContentRequestSort.translated_label(sort)}
          </.dropdown_menu_item>
        </.dropdown_menu>
      </div>

      <.stack id="my-requests" class="@container" phx-update="stream" space="related">
        <%!-- `hidden only:flex`: shown only when it's the stream's sole child (no cards). --%>
        <.requests_empty_state
          filtered={@status_filter != nil or @content_type_filter != nil}
          class="hidden only:flex"
        />

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
      <.live_component
        :if={@content_to_add_to_library}
        id="library-page-add-to-library-modal"
        module={AddToLibraryModalLive}
        content_identity={ContentIdentity.from_content(@content_to_add_to_library)}
        content_title={@content_to_add_to_library.implementation.best_localization.title}
        current_user={@current_user}
        on_close={fn -> send(self(), "close_add_to_library_modal") end}
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
      aria-current={@current == @group && "page"}
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
          @group == :needs_attention && "bg-danger",
          @group == :not_released && "bg-text-subtle",
          @group == :not_found && "bg-warning"
        ]}
        aria-hidden="true"
      ></span>
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
      aria-current={@current == @type && "page"}
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

  # The `:filtered` flavor tells the user a filter is hiding everything; the
  # other greets a user with no requests at all.
  attr :filtered, :boolean, required: true
  attr :class, :any, default: nil

  defp requests_empty_state(%{filtered: true} = assigns) do
    ~H"""
    <.empty id="my-requests-empty" size="sm" class={@class}>
      <:icon><Lucideicons.inbox /></:icon>
      <:title>{dgettext("requests", "No requests match")}</:title>
      <:description>
        {dgettext("requests", "Try clearing some filters, or browse content to add a request.")}
      </:description>
    </.empty>
    """
  end

  defp requests_empty_state(assigns) do
    ~H"""
    <.empty id="my-requests-empty" size="sm" class={@class}>
      <:icon><Lucideicons.inbox /></:icon>
      <:title>{dgettext("requests", "No requests yet")}</:title>
      <:description>
        {dgettext("requests", "Browse movies and shows to request something for your club.")}
      </:description>
    </.empty>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     |> stream_configure(:requests, dom_id: &"request-#{&1.id}")
     |> reset_modals()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
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
       status_filter: Url.parse_url_param(params["status"], ContentRequestStatusGroup.values())
     )
     |> assign(:content_type_filter, Url.parse_url_param(params["type"], ContentType.values()))
     # Reset the keyset stream so a sort/filter change reloads from the first page
     # and replaces the existing cards instead of resuming the previous cursor.
     |> assign(:stream_state, KeysetStreamState.init(@page_size))
     |> load_requests_page()}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    if KeysetStreamState.can_load_more?(socket.assigns.stream_state) do
      {:noreply, socket |> load_requests_page()}
    else
      {:noreply, socket}
    end
  end

  def handle_event("stop-getting-notified", %{"id" => id}, socket) do
    Requests.stop_getting_notified!(id, actor: socket.assigns.current_user)
    {:noreply, socket}
  end

  def handle_event("open_add_to_library_modal", %{"content_id" => content_id}, socket) do
    {:noreply,
     socket
     |> assign(
       content_to_add_to_library:
         Contents.get_content_by_id!(content_id,
           load: [:implementation],
           actor: socket.assigns.current_user
         )
     )}
  end

  @impl true
  # A ContentRequest has been deleted. Remove it from the stream
  def handle_info(
        %Notification{
          data: %ContentRequest{} = request,
          action: %{type: :destroy}
        },
        socket
      ) do
    {:noreply, socket |> stream_delete(:requests, request)}
  end

  # The User stopped getting notified
  def handle_info(
        %Notification{
          data: %RequestSubscriber{content_request_id: content_request_id},
          action: %{type: :destroy}
        },
        socket
      ) do
    {:noreply, socket |> stream_delete_by_dom_id(:requests, "request-#{content_request_id}")}
  end

  # A ContentRequest has been created or updated, or the User became one of its Request
  # Subscribers. Every User gets the notifications of every ContentRequest, so this only
  # shows the ones the User is a Request Subscriber of.
  def handle_info(
        %Notification{
          resource: resource,
          action: %{type: type},
          metadata: %{content_id: content_id}
        },
        socket
      )
      when (resource == ContentRequest and type in [:create, :update]) or
             (resource == RequestSubscriber and type == :create) do
    case Requests.get_current_user_request_for_content(content_id,
           load: @request_fields_to_load,
           actor: socket.assigns.current_user
         ) do
      {:ok, request} ->
        if matches_filters?(request, socket) do
          # Update it if it's already in the list, or add it at the beginning
          {:noreply, socket |> stream_insert(:requests, request, at: 0)}
        else
          {:noreply, socket |> stream_delete(:requests, request)}
        end

      # The User isn't one of its Request Subscribers
      {:error, _} ->
        {:noreply, socket}
    end
  end

  # A content has changed
  # Note that we only match `Content` here, this is because it's the only resource besides ContentRequest
  # on which the cards depend, otherwise we would need to match them as well.
  def handle_info(%Notification{data: %Content{id: content_id}}, socket) do
    # This is slightly ineficient since we make a DB query even when the Contents are not in this
    # stream.
    # This is OK for now. The alternative would be to keep a list of content IDs in the stream
    case Requests.get_current_user_request_for_content(content_id,
           load: @request_fields_to_load,
           actor: socket.assigns.current_user
         ) do
      {:ok, request} ->
        {:noreply, socket |> stream_insert(:requests, request, update_only: true)}

      # Ignore the message if the content is not in the requests list
      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_info("close_add_to_library_modal", socket) do
    {:noreply, socket |> reset_modals()}
  end

  def handle_info(message, socket) do
    # Send updates to all the Live Components we are using on the request cards
    PlayOrRequestButtonLive.handle_pubsub_message(message, socket.assigns.current_user)

    {:noreply, socket}
  end

  defp load_requests_page(socket) do
    stream_state = socket.assigns[:stream_state] || KeysetStreamState.init(@page_size)

    {:ok, new_state, requests} =
      KeysetStreamState.load_page(
        stream_state,
        fn page_options ->
          Requests.list_current_user_content_requests(
            %{
              sort: socket.assigns.sort,
              status_group: socket.assigns.status_filter,
              content_type: socket.assigns.content_type_filter
            },
            load: @request_fields_to_load,
            actor: socket.assigns.current_user,
            page: page_options
          )
        end
      )

    socket
    |> assign(stream_state: new_state)
    |> stream(:requests, requests, reset: stream_state.status == :init)
  end

  defp reset_modals(socket) do
    socket |> assign(content_to_add_to_library: nil)
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
