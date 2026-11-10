defmodule WatchClubWeb.Playlists.PlaylistsPage do
  @moduledoc """
  The Playlists tab: the User's Playlists and the ones shared with them, beside the open one,
  whose Playlist Items show newest added first. Narrow screens show one at a time: the Playlists,
  then the one opened. Without one opened, wide screens show the first.

  The shared unseen ones lead the shared ones, with a New badge, until the User leaves the page,
  since opening it marks them seen.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Playlists.PlaylistLink
  import WatchClubWeb.Playlists.PlaylistsPage.PlaylistDetail

  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive
  alias WatchClubWeb.Helpers.KeysetStreamState
  alias WatchClubWeb.Playlists.PlaylistsPage.PlaylistDialogsLive

  @items_page_size 40

  # A Playlist Item's row: who added it, and its Content's poster, name and progress
  @item_load [
    :added_by,
    content: [
      :actor_progress_status,
      implementation: %{
        load: [
          movie: [:actor_progress],
          sports_event: [:actor_progress],
          tv_show: [:actor_percent_watched]
        ]
      }
    ]
  ]

  @impl true
  def render(assigns) do
    {mine, shared} = Enum.split_with(assigns.playlists, &(&1.owner_id == assigns.current_user.id))
    assigns = assign(assigns, mine: mine, shared: shared, opened?: assigns.opened_id != nil)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      playback_session={@playback_session}
      title={dgettext("nav", "Playlists")}
      space="none"
      class="p-0!"
    >
      <:parent
        :if={@opened?}
        navigate={~p"/playlists"}
        label={dgettext("nav", "Playlists")}
        patch
        narrow_only
      />

      <%!-- Without Playlists, narrow screens show the empty state, which offers New playlist --%>
      <.split_view open={@opened? or @playlists == []}>
        <:list>
          <nav aria-label={dgettext("nav", "Playlists")} class="flex flex-col gap-group px-related">
            <.playlist_group
              title={dgettext("playlists", "Your playlists")}
              playlists={@mine}
              shown={@shown}
              current_user={@current_user}
            >
              <:action>
                <%!-- Its negative margins keep this heading as tall as Shared with you --%>
                <.button
                  id="new-playlist"
                  variant="ghost"
                  size="sm"
                  phx-click={PlaylistDialogsLive.open(:new)}
                  class="-my-related max-md:hidden"
                >
                  <:icon><Lucideicons.plus /></:icon>
                  {dgettext("playlists", "New")}
                </.button>
              </:action>
            </.playlist_group>
            <.playlist_group
              :if={@shared != []}
              title={dgettext("playlists", "Shared with you")}
              playlists={@shared}
              shown={@shown}
              shared_unseen_ids={@shared_unseen_ids}
              current_user={@current_user}
            />
          </nav>
        </:list>
        <:fab>
          <.button
            id="new-playlist-fab"
            size="lg"
            phx-click={PlaylistDialogsLive.open(:new)}
            class="rounded-full! shadow-overlay"
          >
            <:icon><Lucideicons.plus /></:icon>
            {dgettext("playlists", "New")}
          </.button>
        </:fab>
        <:detail>
          <.playlist_detail
            :if={@shown}
            playlist={@shown}
            items={@streams.items}
            items_state={@items_state}
            current_user={@current_user}
          />
          <div :if={!@shown} class="px-page pb-page-y md:pt-group">
            <.empty id="no-playlists">
              <:icon><Lucideicons.list /></:icon>
              <:title>{dgettext("playlists", "No playlists yet")}</:title>
              <:description>
                {dgettext("playlists", "Keep what you want to watch in one place.")}
              </:description>
              <.button
                id="empty-new-playlist"
                variant="secondary"
                phx-click={PlaylistDialogsLive.open(:new)}
              >
                <:icon><Lucideicons.plus /></:icon>
                {dgettext("playlists", "New playlist")}
              </.button>
            </.empty>
          </div>
        </:detail>
      </.split_view>

      <.live_component
        module={PlaylistDialogsLive}
        id={PlaylistDialogsLive.dom_id()}
        playlist={@shown}
        current_user={@current_user}
      />
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :playlists, :list, required: true
  attr :shown, Playlist, default: nil, doc: "the Playlist beside the list"
  attr :shared_unseen_ids, MapSet, default: MapSet.new()
  attr :current_user, User, required: true
  slot :action, doc: "a small button on the right of the title"

  # A titled group of Playlists in the list
  defp playlist_group(assigns) do
    ~H"""
    <div class="flex flex-col gap-tight">
      <div class="flex items-center justify-between gap-related">
        <h2 class="px-related text-xs"><.text_label text={@title} /></h2>
        {render_slot(@action)}
      </div>
      <ul :if={@playlists != []} class="flex flex-col gap-px">
        <li :for={playlist <- @playlists}>
          <.playlist_link
            playlist={playlist}
            current_user={@current_user}
            patch={~p"/playlists/#{playlist.id}"}
            selected={@shown != nil and playlist.id == @shown.id}
            shared_unseen={playlist.id in @shared_unseen_ids}
          />
        </li>
      </ul>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     |> stream_configure(:items, dom_id: &"playlist-item-#{&1.content_id}")
     |> assign(
       shown: nil,
       shared_unseen_ids: MapSet.new(),
       items_state: KeysetStreamState.init(@items_page_size)
     )}
  end

  # The Playlists load on each patch too: a Playlist just created here opens before its
  # notification arrives.
  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:opened_id, params["playlist_id"])
     |> show_playlists!(
       :error,
       dgettext("playlists", "This playlist doesn't exist, or it isn't shared with you.")
     )}
  end

  @impl true
  def handle_event("load_more_items", _params, socket) do
    if KeysetStreamState.can_load_more?(socket.assigns.items_state),
      do: {:noreply, load_items_page(socket)},
      else: {:noreply, socket}
  end

  def handle_event("remove_item", %{"content_id" => content_id}, socket) do
    %{shown: playlist, current_user: user} = socket.assigns

    %PlaylistItem{content: content} =
      Playlists.remove_from_playlist!(playlist.id, content_id,
        return_destroyed?: true,
        load: [content: [:implementation]],
        actor: user
      )

    {:noreply,
     put_flash(
       socket,
       :success,
       dgettext("playlists", "Removed %{content} from %{playlist}.",
         content: content.implementation.best_localization.title,
         playlist: playlist.name
       )
     )}
  end

  # A Playlist the User sees, or what it holds, changed. It may also be new to them, or gone.
  @impl true
  def handle_info(%Notification{resource: resource} = notification, socket)
      when resource in [Playlist, PlaylistAccess, PlaylistItem] do
    {:noreply,
     socket
     |> show_playlists!(:info, gone_message(notification))
     |> update_items(notification)}
  end

  # What a row shows of its Content changed: its poster or its progress
  def handle_info(%Notification{resource: resource} = notification, socket)
      when resource in [Content, WatchProgress] do
    %{shown: playlist, current_user: user} = socket.assigns
    PlayOrRequestButtonLive.handle_pubsub_message(notification, user)

    content_id =
      case notification do
        %{data: %Content{id: id}} -> id
        %{metadata: %{content_id: id}} -> id
      end

    case playlist &&
           Playlists.get_playlist_item!(playlist.id, content_id,
             load: @item_load,
             not_found_error?: false,
             actor: user
           ) do
      %PlaylistItem{} = item -> {:noreply, stream_insert(socket, :items, item, update_only: true)}
      nil -> {:noreply, socket}
    end
  end

  def handle_info(notification, socket) do
    PlayOrRequestButtonLive.handle_pubsub_message(notification, socket.assigns.current_user)
    {:noreply, socket}
  end

  # Loads the Playlists, then shows the one opened, else the first, loading its Playlist Items when
  # it's another one. Leaves for /playlists with the flash when the opened one isn't among them.
  defp show_playlists!(socket, flash_kind, gone_message) do
    socket = load_playlists!(socket)
    %{playlists: playlists, opened_id: opened_id, shown: shown} = socket.assigns

    new_shown =
      if opened_id,
        do: Enum.find(playlists, &(&1.id == opened_id)),
        else: List.first(playlists)

    cond do
      opened_id && !new_shown ->
        socket |> put_flash(flash_kind, gone_message) |> push_patch(to: ~p"/playlists")

      shown && new_shown && shown.id == new_shown.id ->
        assign(socket, :shown, new_shown)

      true ->
        socket |> assign(:shown, new_shown) |> reset_items()
    end
  end

  # Your playlists, then the ones shared with you, the shared unseen ones first, oldest first.
  # Then marks the shared unseen ones seen, so the badge goes but they keep their New badge here.
  # Intentionally small: a User has a handful of Playlists.
  defp load_playlists!(socket) do
    user = socket.assigns.current_user

    playlists =
      Playlists.list_playlists!(
        load: [
          :movie_count,
          :tv_show_count,
          :sports_event_count,
          :owner,
          :shared_unseen_for_actor?,
          accesses: [:user],
          editable_by?: %{user_id: user.id}
        ],
        actor: user
      )

    new_unseen_ids =
      for %{shared_unseen_for_actor?: true} = p <- playlists, into: MapSet.new(), do: p.id

    shared_unseen_ids = MapSet.union(socket.assigns.shared_unseen_ids, new_unseen_ids)

    # Only once the list says which to badge
    if connected?(socket) and MapSet.size(new_unseen_ids) > 0,
      do: Playlists.mark_current_user_playlists_seen!(actor: user)

    socket
    |> assign(:shared_unseen_ids, shared_unseen_ids)
    |> assign(
      :playlists,
      Enum.sort_by(playlists, &{&1.owner_id != user.id, &1.id not in shared_unseen_ids})
    )
    |> WatchClub.PubSub.subscribe_to_playlists(playlists)
  end

  defp gone_message(%Notification{resource: Playlist, action: %{type: :destroy}}),
    do: dgettext("playlists", "This playlist was deleted.")

  defp gone_message(_notification),
    do: dgettext("playlists", "This playlist is no longer shared with you.")

  # A Playlist Item of the shown Playlist came or went. When the Playlist itself changes, its rows
  # reload: they show whether the User can remove them, and who added them once it's shared.
  defp update_items(
         %{assigns: %{shown: %{id: id}}} = socket,
         %Notification{resource: PlaylistItem, action: %{type: :create}, data: %{playlist_id: id}} =
           notification
       ) do
    item = Ash.load!(notification.data, @item_load, actor: socket.assigns.current_user)
    stream_insert(socket, :items, item, at: 0)
  end

  defp update_items(
         %{assigns: %{shown: %{id: id}}} = socket,
         %Notification{
           resource: PlaylistItem,
           action: %{type: :destroy},
           data: %{playlist_id: id}
         } = notification
       ),
       do: stream_delete(socket, :items, notification.data)

  defp update_items(
         %{assigns: %{shown: %{id: id}}} = socket,
         %Notification{resource: Playlist, action: %{type: :update}, data: %{id: id}}
       ),
       do: reset_items(socket)

  defp update_items(socket, _notification), do: socket

  defp reset_items(socket) do
    socket
    |> assign(:items_state, KeysetStreamState.init(@items_page_size))
    |> load_items_page()
  end

  defp load_items_page(%{assigns: %{shown: nil}} = socket),
    do: stream(socket, :items, [], reset: true)

  defp load_items_page(socket) do
    %{items_state: state, shown: playlist, current_user: user} = socket.assigns

    {:ok, new_state, items} =
      KeysetStreamState.load_page(state, fn page ->
        Playlists.list_playlist_items(playlist.id, load: @item_load, page: page, actor: user)
      end)

    socket
    |> assign(:items_state, new_state)
    |> stream(:items, items, reset: state.status == :init)
  end
end
