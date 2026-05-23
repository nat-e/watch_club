defmodule WatchClubWeb.Admin.MediaBrowserPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Settings.SettingsHeader
  import WatchClubWeb.Components.UI.Empty

  alias WatchClub.Media
  alias WatchClubWeb.Admin.MediaBrowserPage.{DetailDrawer, State, Table, Toolbar}

  @page_size 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream_configure(:media_rows, dom_id: &"media-row-#{&1.id}")
     |> assign(:state, State.new())
     |> stream(:media_rows, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    parsed = State.from_params(params)
    # Preserve drawer across patches — the drawer is transient and not in the URL.
    previous_drawer = socket.assigns.state.drawer
    rows = load_media_rows(parsed, socket.assigns.current_user)

    state = %{
      parsed
      | drawer: previous_drawer,
        stream: State.Stream.append(parsed.stream, rows)
    }

    {:noreply,
     socket
     |> assign(:state, state)
     |> stream(:media_rows, rows, reset: true)}
  end

  @impl true
  def handle_event("apply_state", params, socket) do
    # The toolbar form posts every filter + sort field on change. Decode them
    # all through State.from_params so URL params and form params share one
    # schema.
    state = %{socket.assigns.state | filter: nil, sort: nil}
    parsed = State.from_params(form_to_params(params))
    next_state = %{state | filter: parsed.filter, sort: parsed.sort}
    {:noreply, push_patch(socket, to: url_for(next_state))}
  end

  def handle_event("filter_clear", _params, socket) do
    state = %{socket.assigns.state | filter: State.Filter.clear(socket.assigns.state.filter)}
    {:noreply, push_patch(socket, to: url_for(state))}
  end

  def handle_event("filter_remove", %{"field" => field}, socket)
      when field in ~w(search media_type club_id) do
    filter =
      case field do
        "search" -> State.Filter.set(socket.assigns.state.filter, :search, "")
        "media_type" -> State.Filter.set(socket.assigns.state.filter, :media_type, nil)
        "club_id" -> State.Filter.set(socket.assigns.state.filter, :club_id, nil)
      end

    state = %{socket.assigns.state | filter: filter}
    {:noreply, push_patch(socket, to: url_for(state))}
  end

  def handle_event("open_drawer", %{"id" => id}, socket) do
    case Media.get_media(id,
           actor: socket.assigns.current_user,
           load: drawer_load_tree()
         ) do
      {:ok, media} ->
        state = %{
          socket.assigns.state
          | drawer: State.Drawer.open(socket.assigns.state.drawer, media)
        }

        {:noreply, assign(socket, :state, state)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not load Media details.")}
    end
  end

  def handle_event("close_drawer", _params, socket) do
    state = %{socket.assigns.state | drawer: State.Drawer.close(socket.assigns.state.drawer)}
    {:noreply, assign(socket, :state, state)}
  end

  def handle_event("delete_media", _params, socket) do
    drawer = socket.assigns.state.drawer

    case drawer.media do
      nil ->
        {:noreply, socket}

      media ->
        case Media.destroy_media(media, actor: socket.assigns.current_user) do
          :ok ->
            state = %{
              socket.assigns.state
              | drawer: State.Drawer.close(socket.assigns.state.drawer)
            }

            {:noreply,
             socket
             |> assign(:state, state)
             |> stream_delete(:media_rows, media)
             |> put_flash(:info, "Media deleted.")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Could not delete Media.")}
        end
    end
  end

  def handle_event("load_more", _params, socket) do
    # v1: load_more is a no-op placeholder. The :browse action returns up to
    # @page_size rows in one shot; pagination wiring is queued.
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="section"
    >
      <.settings_header
        title="Media Browser"
        description="View and manage all medias on this instance."
      />

      <Toolbar.toolbar state={@state} />

      <div class={[
        "grid gap-cluster",
        @state.drawer.open? && "lg:grid-cols-[minmax(0,1fr)_28rem]"
      ]}>
        <.empty_state :if={State.Stream.empty?(@state.stream)} state={@state} />

        <Table.render
          :if={!State.Stream.empty?(@state.stream)}
          streams={@streams}
          selected_id={selected_id(@state)}
        />

        <DetailDrawer.render :if={@state.drawer.open?} media={@state.drawer.media} />
      </div>
    </Layouts.app>
    """
  end

  defp selected_id(%State{drawer: %State.Drawer{media: %{id: id}}}), do: id
  defp selected_id(_), do: nil

  attr :state, State, required: true

  defp empty_state(%{state: %State{filter: f}} = assigns) do
    if State.Filter.active?(f) do
      filtered_empty_state(assigns)
    else
      no_media_empty_state(assigns)
    end
  end

  defp no_media_empty_state(assigns) do
    ~H"""
    <.empty>
      <:icon><Lucideicons.search /></:icon>
      <:title>You don't have any media yet</:title>
      <:description>
        Configure media imports or automations to add Media to your instance.
      </:description>
      <.button id="empty-state-import-media" navigate={~p"/admin/media/imports"} variant="accent">
        <:icon><Lucideicons.download /></:icon>
        Import Media
      </.button>
    </.empty>
    """
  end

  defp filtered_empty_state(assigns) do
    ~H"""
    <.empty>
      <:icon><Lucideicons.search_x /></:icon>
      <:title>No Media match your filters</:title>
      <:description>Try clearing your filters or searching for something else</:description>
      <.button id="empty-state-import-media" patch={~p"/admin/media"} variant="accent">
        <:icon><Lucideicons.x /></:icon>
        Clear filters
      </.button>
    </.empty>
    """
  end

  # --------------------------------------------------------------------------
  # Helpers
  # --------------------------------------------------------------------------

  defp load_media_rows(%State{} = state, actor) do
    Media.browse_media!(State.browse_arguments(state), actor: actor)
    |> Enum.take(@page_size)
  end

  defp drawer_load_tree do
    [
      video: [
        :video_tracks,
        :audio_tracks,
        :text_tracks,
        movie: [content: [library_items: [library: :club]]],
        tv_show_episode: [
          tv_show: [content: [library_items: [library: :club]]]
        ]
      ],
      ebook: [book: [content: [library_items: [library: :club]]]],
      audiobook: [book: [content: [library_items: [library: :club]]]]
    ]
  end

  defp url_for(%State{} = state) do
    case State.to_query_params(state) do
      params when params == %{} -> ~p"/admin/media"
      params -> ~p"/admin/media?#{params}"
    end
  end

  # Translate the toolbar form params into the URL param schema understood by
  # State.from_params/1. The "sort" form field encodes "<field>:<order>" in one
  # value; split it into sort_by + sort_order.
  defp form_to_params(params) do
    {sort_by, sort_order} = parse_sort(params["sort"])

    %{}
    |> put_if(params["search"], "search")
    |> put_if(params["media_type"], "media_type")
    |> put_if(params["club_id"], "club_id")
    |> put_if(sort_by, "sort_by")
    |> put_if(sort_order, "sort_order")
  end

  defp put_if(map, value, _key) when value in [nil, ""], do: map
  defp put_if(map, value, key), do: Map.put(map, key, value)

  defp parse_sort(nil), do: {nil, nil}
  defp parse_sort(""), do: {nil, nil}

  defp parse_sort(value) when is_binary(value) do
    case String.split(value, ":", parts: 2) do
      [field, order] -> {field, order}
      _ -> {nil, nil}
    end
  end
end
