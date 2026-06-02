defmodule WatchClubWeb.MyRequestsPage do
  use WatchClubWeb, :live_view

  alias WatchClub.Contents.ContentType
  alias WatchClub.Requests
  alias WatchClub.Requests.ContentRequestSort
  alias WatchClub.Requests.ContentRequestStatusGroup
  alias WatchClubWeb.Components.Requests.RequestCard
  alias WatchClubWeb.MyRequestsPage.RequestStreamState
  import WatchClubWeb.Components.Settings.SettingsHeader

  @page_size 25

  # Filter values, derived from the domain enums (plus the "all" no-filter
  # sentinel). Labels and display order live on the enums themselves; the
  # status_group → status collapsing happens server-side, in `for_current_user`.
  # Sort is owned end-to-end by `ContentRequestSort` (param + label + query).
  @valid_status_groups ["all" | Enum.map(ContentRequestStatusGroup.values(), &to_string/1)]
  @valid_types ["all" | Enum.map(ContentType.library_display_order(), &to_string/1)]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Topic published by ContentRequest's `pub_sub` block (prefix "users").
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(WatchClub.PubSub, "users:#{user.id}:requests")

    {:ok,
     socket
     |> stream_configure(:requests, dom_id: &"request-#{&1.id}")
     |> assign(:request_stream, RequestStreamState.initial())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:sort, ContentRequestSort.parse_param(params["sort"]))
      |> assign(:status_filter, validate(params["status"], @valid_status_groups, "all"))
      |> assign(:content_type_filter, validate(params["type"], @valid_types, "all"))

    {:noreply, load_first_page(socket)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    state = socket.assigns.request_stream

    if RequestStreamState.can_load_more?(state) do
      next_state = RequestStreamState.next(state)

      {:noreply,
       socket
       |> assign(:request_stream, next_state)
       |> stream(:requests, RequestStreamState.results(next_state), at: -1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel-request", %{"id" => id}, socket) do
    Requests.cancel_content_request(id, actor: socket.assigns.current_user)
    {:noreply, stream_delete(socket, :requests, %{id: id})}
  end

  @impl true
  def handle_info(_event, socket) do
    # A request was created/cancelled (here or in another tab) — reconcile by
    # reloading the first page.
    {:noreply, load_first_page(socket)}
  end

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
          :for={group <- [:all | ContentRequestStatusGroup.values()]}
          group={group}
          current={@status_filter}
          sort={@sort}
          type={@content_type_filter}
        />
      </.cluster>

      <div class="mb-cluster flex flex-wrap items-center justify-between gap-related">
        <nav aria-label="Filter by content type" class="flex items-center gap-cluster text-sm">
          <.content_type_filter
            :for={type <- [:all | ContentType.library_display_order()]}
            type={type}
            current={@content_type_filter}
            sort={@sort}
            status={@status_filter}
          />
        </nav>

        <.dropdown_menu id="my-requests-sort">
          <:trigger>
            <.button id="my-requests-sort-trigger" variant="ghost" size="sm">
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

      <.empty :if={RequestStreamState.empty?(@request_stream)} size="sm">
        <:icon><Lucideicons.inbox /></:icon>
        <:title>No requests match</:title>
        <:description>Try clearing some filters, or browse content to add a request.</:description>
      </.empty>

      <.stack
        :if={!RequestStreamState.empty?(@request_stream)}
        space="related"
        id="my-requests"
        phx-update="stream"
      >
        <div :for={{dom_id, request} <- @streams.requests} id={dom_id}>
          <RequestCard.request_card request={request} locale={@current_user.settings.locale} />
        </div>
      </.stack>

      <.infinite_scroll_trigger
        :if={RequestStreamState.can_load_more?(@request_stream)}
        id="my-requests-load-more"
        event="load_more"
      />
    </Layouts.app>
    """
  end

  attr :group, :atom, required: true, doc: "`:all`, or a `ContentRequestStatusGroup` value."
  attr :current, :string, required: true
  attr :sort, :atom, required: true
  attr :type, :string, required: true

  defp status_chip(assigns) do
    assigns = assign(assigns, :value, to_string(assigns.group))

    ~H"""
    <.link
      patch={path(sort: @sort, type: @type, status: @value)}
      class={[
        "inline-flex items-center gap-tight rounded-full border px-related py-tight text-sm transition-colors",
        @current == @value && "border-border bg-surface-selected text-text",
        @current != @value &&
          "border-border-subtle bg-surface-inset text-text-muted hover:border-border hover:text-text"
      ]}
    >
      <span
        class={[
          "inline-block size-2 shrink-0 rounded-full",
          @group == :in_progress && "bg-accent",
          @group == :completed && "bg-success",
          @group == :failed && "bg-danger",
          @group in [:all, :unavailable] && "bg-text-subtle"
        ]}
        aria-hidden="true"
      >
      </span>
      {if @group == :all, do: gettext("All"), else: ContentRequestStatusGroup.translated_label(@group)}
    </.link>
    """
  end

  attr :type, :atom, required: true, doc: "`:all`, or a `ContentType` value."
  attr :current, :string, required: true
  attr :sort, :atom, required: true
  attr :status, :string, required: true

  defp content_type_filter(assigns) do
    assigns = assign(assigns, :value, to_string(assigns.type))

    ~H"""
    <.link
      patch={path(sort: @sort, status: @status, type: @value)}
      class={[
        "border-b-2 pb-tight transition-colors",
        @current == @value && "border-accent text-text",
        @current != @value && "border-transparent text-text-muted hover:text-text"
      ]}
    >
      {if @type == :all, do: gettext("All"), else: ContentType.translated_plural_label(@type)}
    </.link>
    """
  end

  # ─── Loading ───────────────────────────────────────────────────────────────

  defp load_first_page(socket) do
    user = socket.assigns.current_user

    page =
      Requests.list_content_requests_for_current_user!(
        action_filters(socket),
        actor: user,
        page: [limit: @page_size]
      )

    state = RequestStreamState.reset(page)

    socket
    |> assign(:request_stream, state)
    |> stream(:requests, RequestStreamState.results(state), reset: true)
  end

  # `:all` collapses to "no filter": status_group is simply omitted (the action
  # only filters when a real group is present) and content_type likewise.
  defp action_filters(socket) do
    %{sort: socket.assigns.sort}
    |> maybe_filter(:status_group, socket.assigns.status_filter)
    |> maybe_filter(:content_type, socket.assigns.content_type_filter)
  end

  defp maybe_filter(filters, _key, "all"), do: filters

  defp maybe_filter(filters, key, value),
    do: Map.put(filters, key, String.to_existing_atom(value))

  # ─── Helpers ──────────────────────────────────────────────────────────────

  defp path(opts) do
    sort = Keyword.get(opts, :sort, ContentRequestSort.default())

    params =
      %{}
      |> maybe_put("sort", ContentRequestSort.to_param(sort), "last_update")
      |> maybe_put("status", Keyword.get(opts, :status, "all"), "all")
      |> maybe_put("type", Keyword.get(opts, :type, "all"), "all")

    if params == %{} do
      ~p"/my-requests"
    else
      ~p"/my-requests?#{params}"
    end
  end

  defp maybe_put(map, _key, value, default) when value == default, do: map
  defp maybe_put(map, key, value, _default), do: Map.put(map, key, value)

  defp validate(value, allowed, default) when is_binary(value) do
    if value in allowed, do: value, else: default
  end

  defp validate(_value, _allowed, default), do: default
end
