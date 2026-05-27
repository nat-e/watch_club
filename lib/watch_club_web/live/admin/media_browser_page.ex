defmodule WatchClubWeb.Admin.MediaBrowserPage do
  use WatchClubWeb, :live_view

  require Logger

  import WatchClubWeb.Admin.MediaBrowserPage.RemoveMediaModal
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
     |> stream_configure(:media_cards, dom_id: &"media-card-#{&1.id}")
     |> assign(:state, State.new())
     |> stream(:media_rows, [])
     |> stream(:media_cards, [])}
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
     |> stream(:media_rows, rows, reset: true)
     |> stream(:media_cards, rows, reset: true)}
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

  def handle_event("open_remove_media_modal", _params, socket) do
    drawer = State.Drawer.open_confirm_remove(socket.assigns.state.drawer)
    {:noreply, assign(socket, :state, %{socket.assigns.state | drawer: drawer})}
  end

  def handle_event("close_remove_media_modal", _params, socket) do
    drawer = State.Drawer.close_confirm_remove(socket.assigns.state.drawer)
    {:noreply, assign(socket, :state, %{socket.assigns.state | drawer: drawer})}
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
             |> stream_delete(:media_cards, media)
             |> put_flash(:info, "Media deleted.")}

          {:error, reason} ->
            Logger.error("Failed to delete Media #{media.id}: #{inspect(reason)}")

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

      <.empty_state :if={State.Stream.empty?(@state.stream)} state={@state} />

      <div
        :if={!State.Stream.empty?(@state.stream)}
        class={[
          "grid gap-cluster items-start",
          @state.drawer.open? &&
            "lg:grid-cols-[minmax(0,1fr)_26rem] xl:grid-cols-[minmax(0,1fr)_32rem] 2xl:grid-cols-[minmax(0,1fr)_36rem]"
        ]}
      >
        <Table.render
          streams={@streams}
          selected_id={selected_id(@state)}
          drawer_open?={@state.drawer.open?}
          locale={@current_user.settings.locale}
        />

        <%= if @state.drawer.open? do %>
          <button
            type="button"
            phx-click="close_drawer"
            aria-label="Close detail panel"
            class="fixed inset-0 z-40 bg-scrim backdrop-blur-sm lg:hidden"
          >
          </button>
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Media detail"
            phx-window-keydown="close_drawer"
            phx-key="escape"
            class={[
              "fixed inset-y-0 right-0 z-50 w-full max-w-[32rem] overflow-y-auto",
              "lg:static lg:z-auto lg:max-w-none lg:overflow-visible"
            ]}
          >
            <DetailDrawer.render
              media={@state.drawer.media}
              locale={@current_user.settings.locale}
            />
          </div>
        <% end %>
      </div>

      <.remove_media_modal :if={@state.drawer.confirm_remove_open?} />
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
      <.button id="empty-state-import-media" navigate={~p"/admin/media/sources"} variant="accent">
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
        :default_video_track,
        :audio_tracks,
        :text_tracks,
        movie: [:best_localization, content: [library_items: [library: :club]]],
        tv_show_episode: [
          tv_show: [:best_localization, content: [library_items: [library: :club]]]
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
