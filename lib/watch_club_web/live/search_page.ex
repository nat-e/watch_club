defmodule WatchClubWeb.SearchPage do
  @moduledoc """
  Every result of a search. Browse's search field opens it, and stays in the bar to search again.
  `library=1` keeps only the Library.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Search.SearchResultRow
  import WatchClubWeb.Components.Search.SearchScopes
  import WatchClubWeb.Components.Search.SearchStatus

  alias WatchClub.Contents.SearchResultsPage

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      class="max-w-6xl @container pt-0! md:pt-group!"
      space="group"
      title={dgettext("search", "Search")}
      search
    >
      <.search_scopes
        id="search-page-scopes"
        has_media={@has_media?}
        on_toggle="toggle_has_media"
      />
      <.search_status
        id="search-page-status"
        status={@status}
        query={@query}
        result_count={@result_count}
        on_retry="retry"
      />

      <div id="search-results" phx-update="stream" class="flex flex-col gap-tight">
        <.search_result_row
          :for={{dom_id, result} <- @streams.search_results}
          id={dom_id}
          result={result}
          overview
        />
      </div>

      <.infinite_scroll_trigger
        :if={@status == :ok and @page < @total_pages}
        id="search-load-more"
        event="load_more"
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     stream_configure(socket, :search_results,
       dom_id: &"search-result-#{&1.identity.type}-#{&1.identity.external_id}"
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(Url.search_params(params))
     |> search()}
  end

  @impl true
  def handle_event("toggle_has_media", _params, socket) do
    %{query: query, has_media?: has_media?} = socket.assigns
    {:noreply, push_patch(socket, to: Url.search_link(query, !has_media?), replace: true)}
  end

  def handle_event("retry", _params, socket) do
    {:noreply, search(socket)}
  end

  # The trigger can fire again before the last page has loaded
  def handle_event("load_more", _params, %{assigns: %{page: page, total_pages: total}} = socket)
      when page >= total,
      do: {:noreply, socket}

  def handle_event("load_more", _params, socket) do
    %{query: query, has_media?: has_media?, page: page, current_user: user} = socket.assigns

    case Contents.search_content(%{query: query, has_media?: has_media?, page: page + 1},
           actor: user
         ) do
      {:ok, %SearchResultsPage{} = results_page} ->
        {:noreply,
         socket
         |> assign(page: results_page.page, total_pages: results_page.total_pages)
         |> stream(:search_results, results_page.results)}

      # The trigger asks again when it scrolls back into view
      {:error, _error} ->
        {:noreply, socket}
    end
  end

  defp search(socket) do
    socket =
      socket
      |> assign(page: 0, total_pages: 0, result_count: 0)
      |> stream(:search_results, [], reset: true)

    %{query: query, has_media?: has_media?, current_user: user} = socket.assigns

    case query do
      "" ->
        socket |> cancel_async(:search) |> assign(:status, :idle)

      query ->
        otel_context = OpenTelemetry.Ctx.get_current()

        socket
        |> assign(:status, :loading)
        |> start_async(:search, fn ->
          OpenTelemetry.Ctx.attach(otel_context)
          Contents.search_content!(%{query: query, has_media?: has_media?}, actor: user)
        end)
    end
  end

  @impl true
  def handle_async(:search, {:ok, %SearchResultsPage{} = results_page}, socket) do
    {:noreply,
     socket
     |> assign(
       status: :ok,
       page: results_page.page,
       total_pages: results_page.total_pages,
       result_count: length(results_page.results)
     )
     |> stream(:search_results, results_page.results, reset: true)}
  end

  def handle_async(:search, {:exit, {:shutdown, :cancel}}, socket), do: {:noreply, socket}

  def handle_async(:search, {:exit, _reason}, socket) do
    {:noreply, assign(socket, :status, :error)}
  end
end
