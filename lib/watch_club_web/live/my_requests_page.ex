defmodule WatchClubWeb.MyRequestsPage do
  use WatchClubWeb, :live_view

  alias WatchClubWeb.Components.Requests.RequestCard
  import WatchClubWeb.Components.Settings.SettingsHeader

  # UI-level status groups. Card-level labels remain finer-grained
  # (queued / downloading X% / processing) but the page filter collapses
  # the three "in-flight" states into a single "in_progress" pill, and
  # "not_released" + "not_found" into "unavailable".
  @in_progress_statuses ~w(requested downloading processing)
  @unavailable_statuses ~w(not_released not_found)
  @group_order ~w(in_progress available failed unavailable)
  @valid_status_groups ["all" | @group_order]
  @valid_types ~w(all movie tv_show book)
  @valid_sorts ~w(last_update created)
  @sort_labels %{"last_update" => "Last update", "created" => "Created"}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :requests, fixtures())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:sort, validate(params["sort"], @valid_sorts, "last_update"))
     |> assign(:status_filter, validate(params["status"], @valid_status_groups, "all"))
     |> assign(:content_type_filter, validate(params["type"], @valid_types, "all"))}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    visible = filter_requests(assigns)
    counts = count_by_group(assigns.requests)
    total = length(assigns.requests)

    assigns =
      assigns
      |> assign(:visible_requests, visible)
      |> assign(:counts, counts)
      |> assign(:total, total)
      |> assign(:group_order, @group_order)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      class="max-w-layout-page"
    >
      <.settings_header
        title="My Requests"
        description=""
      />
      <.cluster space="tight" aria-label="Filter by status" class="mb-related">
        <.status_chip
          sort={@sort}
          type={@content_type_filter}
          status="all"
          current={@status_filter}
          count={@total}
        >
          All
        </.status_chip>
        <.status_chip
          :for={group <- @group_order}
          sort={@sort}
          type={@content_type_filter}
          status={group}
          current={@status_filter}
          count={@counts[group] || 0}
        >
          {group_label(group)}
        </.status_chip>
      </.cluster>

      <div class="mb-cluster flex flex-wrap items-center justify-between gap-related">
        <nav aria-label="Filter by content type" class="flex items-center gap-cluster text-sm">
          <.link
            :for={{type, label} <- type_options()}
            patch={path(sort: @sort, status: @status_filter, type: type)}
            class={[
              "border-b-2 pb-tight transition-colors",
              @content_type_filter == type && "border-accent text-text",
              @content_type_filter != type &&
                "border-transparent text-text-muted hover:text-text"
            ]}
          >
            {label}
          </.link>
        </nav>

        <.dropdown_menu id="my-requests-sort">
          <:trigger>
            <.button id="my-requests-sort-trigger" variant="ghost" size="sm">
              <:icon><Lucideicons.arrow_up_down /></:icon>
              Sort: {sort_label(@sort)}
              <:icon position="end"><Lucideicons.chevron_down /></:icon>
            </.button>
          </:trigger>
          <.dropdown_menu_item
            :for={key <- ["last_update", "created"]}
            id={"my-requests-sort-#{key}"}
            patch={path(status: @status_filter, type: @content_type_filter, sort: key)}
          >
            <Lucideicons.check class={if @sort == key, do: "", else: "invisible"} />
            {sort_label(key)}
          </.dropdown_menu_item>
        </.dropdown_menu>
      </div>

      <.empty :if={@visible_requests == []} size="sm">
        <:icon><Lucideicons.inbox /></:icon>
        <:title>No requests match</:title>
        <:description>Try clearing some filters, or browse content to add a request.</:description>
      </.empty>

      <.stack :if={@visible_requests != []} space="related">
        <RequestCard.request_card
          :for={req <- @visible_requests}
          id={"my-requests-card-#{req.id}"}
          content_type={req.content_type}
          title={req.title}
          year={req.year}
          runtime={req.runtime}
          country_flag={req.country_flag}
          language_label={req.language_label}
          poster_url={req.poster_url}
          status={req.status}
          progress={Map.get(req, :progress)}
          requested_at_label={Map.get(req, :requested_at_label)}
        />
      </.stack>

      <.infinite_scroll_trigger
        :if={@visible_requests != []}
        id="my-requests-load-more"
        event="load_more"
      />
    </Layouts.app>
    """
  end

  attr :sort, :string, required: true
  attr :type, :string, required: true
  attr :status, :string, required: true
  attr :current, :string, required: true
  attr :count, :integer, required: true
  slot :inner_block, required: true

  defp status_chip(assigns) do
    ~H"""
    <.link
      patch={path(sort: @sort, type: @type, status: @status)}
      class={[
        "inline-flex items-center gap-tight rounded-full border px-related py-tight text-sm transition-colors",
        @current == @status && "border-border bg-surface-selected text-text",
        @current != @status &&
          "border-border-subtle bg-surface-inset text-text-muted hover:border-border hover:text-text"
      ]}
    >
      <span
        class={["inline-block size-2 shrink-0 rounded-full", status_dot_class(@status)]}
        aria-hidden="true"
      >
      </span>
      {render_slot(@inner_block)}
      <span class="tabular-nums text-text-subtle">{@count}</span>
    </.link>
    """
  end

  # ─── Helpers ──────────────────────────────────────────────────────────────

  defp path(opts) do
    params =
      %{}
      |> maybe_put("sort", Keyword.get(opts, :sort, "last_update"), "last_update")
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

  defp filter_requests(assigns) do
    Enum.filter(assigns.requests, fn req ->
      status_match?(assigns.status_filter, req.status) and
        type_match?(assigns.content_type_filter, req.content_type)
    end)
  end

  defp status_match?("all", _status), do: true
  defp status_match?("in_progress", status), do: status in @in_progress_statuses
  defp status_match?("unavailable", status), do: status in @unavailable_statuses
  defp status_match?(group, status), do: group == status

  defp type_match?("all", _type), do: true
  defp type_match?(filter, type), do: filter == to_string(type)

  defp count_by_group(requests) do
    Enum.reduce(requests, %{}, fn req, acc ->
      Map.update(acc, group_for(req.status), 1, &(&1 + 1))
    end)
  end

  defp group_for(status) when status in @in_progress_statuses, do: "in_progress"
  defp group_for(status) when status in @unavailable_statuses, do: "unavailable"
  defp group_for(status), do: status

  defp request_word(1), do: "request"
  defp request_word(_), do: "requests"

  defp group_label("in_progress"), do: "In progress"
  defp group_label("available"), do: "Available"
  defp group_label("failed"), do: "Failed"
  defp group_label("unavailable"), do: "Unavailable"

  defp status_dot_class("all"), do: "bg-text-subtle"
  defp status_dot_class("in_progress"), do: "bg-accent"
  defp status_dot_class("available"), do: "bg-success"
  defp status_dot_class("failed"), do: "bg-danger"
  defp status_dot_class("unavailable"), do: "bg-text-subtle"

  defp type_options do
    [
      {"all", "All"},
      {"movie", "Movies"},
      {"tv_show", "TV Shows"},
      {"book", "Books"}
    ]
  end

  defp sort_label(key), do: Map.get(@sort_labels, key, key)

  defp fixtures do
    [
      %{
        id: "dune-part-three",
        status: "not_released",
        content_type: :movie,
        title: "Dune: Part Three",
        year: 2026,
        runtime: nil,
        country_flag: "🇺🇸",
        language_label: "English",
        poster_url: tmdb_poster("/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg"),
        requested_at_label: "2 hours ago"
      },
      %{
        id: "dune-part-two",
        status: "requested",
        content_type: :movie,
        title: "Dune: Part Two",
        year: 2024,
        runtime: "2h 47m",
        country_flag: "🇺🇸",
        language_label: "English",
        poster_url: tmdb_poster("/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg"),
        requested_at_label: "5 hours ago"
      },
      %{
        id: "the-matrix",
        status: "downloading",
        progress: 48,
        content_type: :movie,
        title: "The Matrix",
        year: 1999,
        runtime: "2h 16m",
        country_flag: "🇺🇸",
        language_label: "English",
        poster_url: tmdb_poster("/aOIuZAjPaRIE6CMzbazvcHuHXDc.jpg"),
        requested_at_label: "yesterday"
      },
      %{
        id: "severance",
        status: "processing",
        content_type: :tv_show,
        title: "Severance",
        year: 2022,
        runtime: "S1–S2 · 19 ep",
        country_flag: "🇺🇸",
        language_label: "English",
        poster_url: tmdb_poster("/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg"),
        requested_at_label: "3 days ago"
      },
      %{
        id: "interstellar",
        status: "available",
        content_type: :movie,
        title: "Interstellar",
        year: 2014,
        runtime: "2h 49m",
        country_flag: "🇺🇸",
        language_label: "English",
        poster_url: tmdb_poster("/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg"),
        requested_at_label: "1 week ago"
      },
      %{
        id: "annihilation",
        status: "failed",
        content_type: :movie,
        title: "Annihilation",
        year: 2018,
        runtime: "1h 55m",
        country_flag: "🇺🇸",
        language_label: "English",
        poster_url: tmdb_poster("/4YRplSk6BhH6PRuE9gfyw9byUJ6.jpg"),
        requested_at_label: "5 days ago"
      },
      %{
        id: "blade-runner-2049",
        status: "available",
        content_type: :movie,
        title: "Blade Runner 2049",
        year: 2017,
        runtime: "2h 44m",
        country_flag: "🇺🇸",
        language_label: "English",
        poster_url: tmdb_poster("/gajva2L0rPYkEWjzgFlBXCAVBE5.jpg"),
        requested_at_label: "2 weeks ago"
      },
      %{
        id: "foundation",
        status: "not_found",
        content_type: :tv_show,
        title: "Foundation",
        year: 2021,
        runtime: "S1–S3 · 30 ep",
        country_flag: "🇺🇸",
        language_label: "English",
        poster_url: tmdb_poster("/tg9I5pOY4M9CKj8U0cxVBTsm5eh.jpg"),
        requested_at_label: "3 weeks ago"
      },
      %{
        id: "dune-2021",
        status: "downloading",
        progress: 12,
        content_type: :movie,
        title: "Dune",
        year: 2021,
        runtime: "2h 35m",
        country_flag: "🇺🇸",
        language_label: "English",
        poster_url: tmdb_poster("/gDzOcq0pfeCeqMBwKIJlSmQpjkZ.jpg"),
        requested_at_label: "12 minutes ago"
      }
    ]
  end

  defp tmdb_poster(path), do: "https://image.tmdb.org/t/p/w500#{path}"
end
