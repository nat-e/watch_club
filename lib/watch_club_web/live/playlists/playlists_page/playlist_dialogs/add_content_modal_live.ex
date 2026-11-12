defmodule WatchClubWeb.Playlists.PlaylistsPage.PlaylistDialogs.AddContentModalLive do
  @moduledoc """
  Add to Playlist from the Playlist: the User searches as on the search page, and a click on a
  result adds it to the Playlist, or takes it out once it's there.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Search.SearchResultRow, only: [search_result_summary: 1]
  import WatchClubWeb.Components.Search.SearchScopes
  import WatchClubWeb.Components.Search.SearchStatus

  alias WatchClub.Contents.{SearchResult, SearchResultsPage}
  alias WatchClubWeb.Hooks.Flash

  attr :id, :string, required: true
  attr :playlist, Playlist, required: true
  attr :current_user, User, required: true
  attr :on_close, JS, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal
        id={@id}
        size="md"
        phone="full_screen"
        on_close={@on_close}
        class="w-full md:h-[min(44rem,85svh)]"
      >
        <:title>{dgettext("playlists", "Add to %{playlist}", playlist: @playlist.name)}</:title>

        <%!-- As wide as the results, which bleed into the padding, so they scroll under it --%>
        <div class="sticky top-0 z-10 -mx-related flex flex-col gap-group bg-surface-overlay px-related pb-related">
          <.form
            id={"#{@id}-search"}
            for={to_form(%{})}
            layout="none"
            role="search"
            autocomplete="off"
            phx-change="search"
            phx-submit="search"
            phx-target={@myself}
          >
            <div class="relative">
              <Lucideicons.search
                aria-hidden="true"
                class="pointer-events-none absolute top-1/2 left-3 size-icon-sm -translate-y-1/2 text-text-subtle"
              />
              <.input
                id={"#{@id}-query"}
                name="query"
                value={@query}
                type="search"
                placeholder={dgettext("search", "Search")}
                aria-label={dgettext("search", "Search")}
                autofocus
                phx-debounce="300"
                class="pl-9!"
              />
            </div>
          </.form>
          <.search_scopes
            id={"#{@id}-scopes"}
            scope={@scope}
            on_scope={JS.push("change_scope", target: @myself)}
            has_media={@has_media?}
            on_toggle={JS.push("toggle_has_media", target: @myself)}
          />
        </div>

        <.search_status
          id={"#{@id}-status"}
          status={@status}
          query={@query}
          result_count={length(@results)}
          on_retry={JS.push("retry", target: @myself)}
          hint={dgettext("playlists", "Search by title, then pick what to add.")}
        />
        <ul
          :if={@status == :ok and @results != []}
          id={"#{@id}-results"}
          aria-label={dgettext("search", "Search results")}
          class="-mx-related flex flex-col gap-px"
        >
          <li :for={result <- @results}>
            <%!-- Pressed while the Playlist holds it --%>
            <button
              id={"#{@id}-#{result.identity.type}-#{result.identity.external_id}"}
              type="button"
              aria-pressed={to_string(Map.has_key?(@held_content_ids, result.identity))}
              phx-click="toggle"
              phx-value-type={result.identity.type}
              phx-value-external_id={result.identity.external_id}
              phx-target={@myself}
              class="group/result flex w-full items-center gap-group rounded-control p-related text-left transition-colors hover:bg-surface-hover focus-visible:-outline-offset-2 aria-pressed:bg-surface-selected phx-click-loading:pointer-events-none phx-click-loading:opacity-60"
            >
              <.search_result_summary result={result} />
              <Lucideicons.circle_plus class="size-icon shrink-0 text-text-muted group-aria-pressed/result:hidden" />
              <Lucideicons.circle_check class="hidden size-icon shrink-0 text-success group-aria-pressed/result:block" />
            </button>
          </li>
        </ul>

        <:footer class="mt-auto">
          <.button id={"#{@id}-done"} data-modal-close>{dgettext("playlists", "Done")}</.button>
        </:footer>
      </.modal>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(Url.search_params(%{}))
     # Intentionally small: a search's first page
     |> assign(status: :idle, results: [], held_content_ids: %{})}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket),
    do: {:noreply, socket |> assign(:query, query) |> search()}

  def handle_event("change_scope", %{"scope" => scope}, socket) do
    {:ok, scope} = SearchContentType.match(scope)
    {:noreply, socket |> assign(:scope, scope) |> search()}
  end

  def handle_event("toggle_has_media", _params, socket),
    do: {:noreply, socket |> update(:has_media?, &(!&1)) |> search()}

  def handle_event("retry", _params, socket), do: {:noreply, search(socket)}

  def handle_event("toggle", %{"type" => type, "external_id" => external_id}, socket) do
    result =
      Enum.find(
        socket.assigns.results,
        &(to_string(&1.identity.type) == type and &1.identity.external_id == external_id)
      )

    {:noreply, toggle(socket, result)}
  end

  # Takes the result out of the Playlist when it holds it, else adds it
  defp toggle(socket, %SearchResult{identity: identity} = result) do
    %{held_content_ids: held, playlist: playlist, current_user: user} = socket.assigns

    case held do
      %{^identity => content_id} ->
        Playlists.remove_from_playlist!(playlist.id, content_id, actor: user)
        assign(socket, :held_content_ids, Map.delete(held, identity))

      # Adding fetches the Content from its Metadata Provider when WatchClub doesn't have it yet
      %{} ->
        case Playlists.add_to_playlist(playlist.id, identity, actor: user) do
          {:ok, item} ->
            assign(socket, :held_content_ids, Map.put(held, identity, item.content_id))

          {:error, _error} ->
            Flash.send_flash(
              :error,
              dgettext("playlists", "Couldn't add %{content}. Try again.", content: result.title)
            )

            socket
        end
    end
  end

  # A new search replaced the results before the click arrived
  defp toggle(socket, nil), do: socket

  @impl true
  def handle_async(:search, {:ok, {results, held_content_ids}}, socket),
    do:
      {:noreply,
       assign(socket, status: :ok, results: results, held_content_ids: held_content_ids)}

  def handle_async(:search, {:exit, {:shutdown, :cancel}}, socket), do: {:noreply, socket}

  def handle_async(:search, {:exit, _reason}, socket),
    do: {:noreply, assign(socket, status: :error, results: [])}

  # The results, and the ids of the Content the Playlist holds among them, by identity
  defp search(socket) do
    %{query: query, scope: scope, has_media?: has_media?, playlist: playlist, current_user: user} =
      socket.assigns

    case String.trim(query) do
      "" ->
        socket |> cancel_async(:search) |> assign(status: :idle, results: [])

      query ->
        otel_context = OpenTelemetry.Ctx.get_current()

        socket
        |> assign(:status, :loading)
        |> start_async(:search, fn ->
          OpenTelemetry.Ctx.attach(otel_context)

          %SearchResultsPage{results: results} =
            Contents.search_content!(
              %{query: query, content_type: scope, has_media?: has_media?},
              actor: user
            )

          held_content_ids =
            playlist.id
            |> Playlists.list_playlist_items_for_contents!(Enum.map(results, & &1.identity),
              load: [:content],
              actor: user
            )
            |> Map.new(&{ContentIdentity.from_content(&1.content), &1.content_id})

          {results, held_content_ids}
        end)
    end
  end
end
