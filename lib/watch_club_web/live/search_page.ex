defmodule WatchClubWeb.SearchPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.ContentTypeBadge
  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.SearchResultsPage
  alias WatchClub.Integrations.Tmdb.{MovieSearchResult, TvSearchResult}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      class="max-w-6xl"
    >
      <.section
        description={
          raw(
            dgettext("search", "Showing results for %{query}",
              query: gtspan("“#{@query}”", "font-bold text-text")
            )
          )
        }
        surface="transparent"
        padding="related"
      >
        <.stack
          id="search-results"
          phx-update="stream"
          space="related"
        >
          <%!-- `hidden only:flex`: shown only when it's the stream's sole child (no cards). --%>
          <.no_results query={@query} search_error?={@search_error?} class="hidden only:flex" />

          <.search_result_card
            :for={{dom_id, result} <- @streams.search_results}
            id={dom_id}
            result={result}
          />
        </.stack>

        <.infinite_scroll_trigger
          :if={can_load_more?(assigns)}
          id="search-load-more"
          event="load_more"
        />
      </.section>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :result, :any, required: true

  defp search_result_card(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={Url.content_details_link(content_identity(@result))}
      class="flex items-start gap-group rounded-lg py-related transition-colors hover:bg-surface-hover focus-visible:bg-surface-hover focus-visible:outline-none"
    >
      <.tmdb_poster
        path={@result.poster_path}
        size="w185"
        class="w-24 shrink-0 border border-border-subtle sm:w-30"
      />
      <.stack space="related" class="min-w-0 flex-1">
        <div class="flex flex-wrap items-center gap-related">
          <span class="font-semibold text-text">{result_title(@result)}</span>
          <.content_type_badge type={content_type(@result)} />
        </div>
        <p class="line-clamp-4 text-sm text-text-muted sm:line-clamp-6">
          {@result.overview}
        </p>
      </.stack>
    </.link>
    """
  end

  attr :query, :string, required: true
  attr :search_error?, :boolean, required: true
  attr :class, :any, default: nil

  defp no_results(%{search_error?: true} = assigns) do
    ~H"""
    <.empty id="search-results-status" class={@class}>
      <:icon><Lucideicons.triangle_alert /></:icon>
      <:description>
        {dgettext("search", "There was an error searching for your content")}
      </:description>
      <.button id="search-retry" variant="secondary" phx-click="retry">
        {dgettext("default", "Try again")}
      </.button>
    </.empty>
    """
  end

  defp no_results(assigns) do
    ~H"""
    <.empty id="search-results-status" class={@class}>
      <:icon><Lucideicons.search_x /></:icon>
      <:title>
        {dgettext("search", "No results")}
      </:title>
      <:description>
        {raw(
          dgettext("search", "We didn't find any content for %{query}",
            query: gtspan("“#{@query}”", "font-bold text-text")
          )
        )}
      </:description>
    </.empty>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream_configure(:search_results, dom_id: &to_string(&1.id))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(
       query: params["query"] || "",
       content_type:
         Url.parse_url_param(params["type"], SearchContentType.values(), :movies_and_shows),
       page: 0,
       total_pages: 0,
       search_error?: false
     )
     |> load_page(1)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    if can_load_more?(socket.assigns) do
      {:noreply, load_page(socket, socket.assigns.page + 1)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("retry", _params, socket) do
    {:noreply, load_page(socket, 1)}
  end

  defp load_page(socket, page_number) do
    case Contents.search_content(
           %{
             query: socket.assigns.query,
             content_type: socket.assigns.content_type,
             page: page_number
           },
           actor: socket.assigns.current_user
         ) do
      {:ok, %SearchResultsPage{results: results, page: page, total_pages: total_pages}} ->
        socket
        |> assign(page: page, total_pages: total_pages, search_error?: false)
        |> stream(:search_results, results, reset: page_number == 1)

      {:error, _error} ->
        socket = assign(socket, :search_error?, true)
        if page_number == 1, do: stream(socket, :search_results, [], reset: true), else: socket
    end
  end

  defp can_load_more?(assigns) do
    not assigns.search_error? and assigns.page < assigns.total_pages
  end

  defp content_identity(%MovieSearchResult{id: tmdb_id}), do: ContentIdentity.for_movie(tmdb_id)
  defp content_identity(%TvSearchResult{id: tmdb_id}), do: ContentIdentity.for_tv_show(tmdb_id)

  defp content_type(%MovieSearchResult{}), do: :movie
  defp content_type(%TvSearchResult{}), do: :tv_show

  defp result_title(%MovieSearchResult{title: title, release_date: nil}), do: title

  defp result_title(%MovieSearchResult{title: title, release_date: date}),
    do: "#{title} (#{date.year})"

  defp result_title(%TvSearchResult{name: name, first_air_date: nil}), do: name

  defp result_title(%TvSearchResult{name: name, first_air_date: date}),
    do: "#{name} (#{date.year})"
end
