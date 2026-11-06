defmodule WatchClubWeb.Playlists.PlaylistsPage do
  @moduledoc """
  The Playlists tab: the User's Playlists and the ones shared with them, beside the open one,
  whose Playlist Items show newest added first. Narrow screens show one at a time: the Playlists,
  then the one opened. Without one opened, wide screens show the first.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Playlists.PlaylistLink
  import WatchClubWeb.Playlists.PlaylistsPage.DeletePlaylistModal
  import WatchClubWeb.Playlists.PlaylistsPage.PlaylistFormModal

  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive
  alias WatchClubWeb.Components.UI.IconPickerLive
  alias WatchClubWeb.Helpers.KeysetStreamState

  @items_page_size 40

  # A Playlist Item's row: who added it, and its Content's poster, name, progress, and whether
  # it can be played
  @item_load [
    :added_by,
    content: [
      :has_media?,
      :actor_progress_status,
      implementation: %{load: [movie: [:actor_progress], tv_show: [:actor_percent_watched]]}
    ]
  ]

  @impl true
  def render(assigns) do
    playlists = assigns.mine ++ assigns.shared

    assigns =
      assign(assigns,
        opened?: assigns.opened_id != nil,
        playlist: Enum.find(playlists, &(&1.id == assigns.shown_id))
      )

    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
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

      <div class="@container">
        <div class="flex md:h-[calc(100svh-var(--wc-app-bar-height))]">
          <aside
            aria-label={dgettext("nav", "Playlists")}
            class={[
              "w-full flex-col gap-group border-border-subtle pb-group max-md:pb-20 md:overflow-y-auto md:pt-group [scrollbar-color:var(--color-surface-hover)_transparent] [scrollbar-width:thin] @4xl:flex @4xl:w-72 @4xl:shrink-0 @4xl:border-r",
              @opened? && "hidden",
              !@opened? && "flex"
            ]}
          >
            <nav aria-label={dgettext("nav", "Playlists")} class="flex flex-col gap-group px-related">
              <div class="flex flex-col gap-tight">
                <div class="flex items-center justify-between gap-related">
                  <h2 class="px-related text-xs">
                    <.text_label text={dgettext("playlists", "Your playlists")} />
                  </h2>
                  <%!-- Its negative margins keep this heading as tall as Shared with you --%>
                  <.button
                    id="new-playlist"
                    variant="ghost"
                    size="sm"
                    phx-click="new_playlist"
                    class="-my-related max-md:hidden"
                  >
                    <:icon><Lucideicons.plus /></:icon>
                    {dgettext("playlists", "New")}
                  </.button>
                </div>
                <ul :if={@mine != []} class="flex flex-col gap-px">
                  <li :for={playlist <- @mine}>
                    <.playlist_link
                      playlist={playlist}
                      current_user={@current_user}
                      patch={~p"/playlists/#{playlist.id}"}
                      selected={playlist.id == @shown_id}
                      opened={@opened?}
                    />
                  </li>
                </ul>
              </div>
              <div :if={@shared != []} class="flex flex-col gap-tight">
                <h2 class="px-related text-xs">
                  <.text_label text={dgettext("playlists", "Shared with you")} />
                </h2>
                <ul class="flex flex-col gap-px">
                  <li :for={playlist <- @shared}>
                    <.playlist_link
                      playlist={playlist}
                      current_user={@current_user}
                      patch={~p"/playlists/#{playlist.id}"}
                      selected={playlist.id == @shown_id}
                      opened={@opened?}
                    />
                  </li>
                </ul>
              </div>
            </nav>
          </aside>

          <%!-- On phones, the list's main action floats above the tabs --%>
          <div
            :if={!@opened?}
            class="fixed right-page bottom-[calc(var(--wc-tab-bar-height)+var(--spacing-group))] z-30 md:hidden"
          >
            <.button
              id="new-playlist-fab"
              size="lg"
              phx-click="new_playlist"
              class="rounded-full! shadow-overlay"
            >
              <:icon><Lucideicons.plus /></:icon>
              {dgettext("playlists", "New")}
            </.button>
          </div>

          <div class={[
            "min-w-0 flex-1 flex-col md:overflow-y-auto [scrollbar-color:var(--color-surface-hover)_transparent] [scrollbar-width:thin] @4xl:flex",
            @opened? && "flex",
            !@opened? && "hidden"
          ]}>
            <.playlist_detail
              :if={@playlist}
              playlist={@playlist}
              items={@streams.items}
              items_state={@items_state}
              current_user={@current_user}
            />
            <div :if={!@playlist} class="px-page pb-page-y md:pt-group">
              <.empty id="no-playlists">
                <:icon><Lucideicons.list /></:icon>
                <:title>{dgettext("playlists", "No playlists yet")}</:title>
                <:description>
                  {dgettext("playlists", "Keep what you want to watch in one place.")}
                </:description>
                <.button id="empty-new-playlist" variant="secondary" phx-click="new_playlist">
                  <:icon><Lucideicons.plus /></:icon>
                  {dgettext("playlists", "New playlist")}
                </.button>
              </.empty>
            </div>
          </div>
        </div>
      </div>

      <.playlist_form_modal :if={@playlist_form} form={@playlist_form} icon={@playlist_icon} />
      <.live_component
        :if={@icon_picker_open?}
        module={IconPickerLive}
        id="playlist-icon-picker"
        selected_icon={@playlist_icon}
        title={dgettext("playlists", "Choose an icon")}
        description={dgettext("playlists", "Select an icon for your playlist")}
        on_select={JS.push("icon_selected")}
        on_close={JS.push("close_icon_picker")}
      />
      <.delete_playlist_modal
        :if={@deleting?}
        playlist={@playlist}
        locale={@current_user.settings.locale}
      />
    </Layouts.app>
    """
  end

  attr :playlist, Playlist, required: true
  attr :items, :any, required: true, doc: "the stream of its Playlist Items"
  attr :items_state, KeysetStreamState, required: true
  attr :current_user, User, required: true

  # Its name, who has it and what it holds, the owner's actions, then its Playlist Items
  defp playlist_detail(assigns) do
    %{playlist: playlist, current_user: user} = assigns

    assigns =
      assign(assigns,
        owner?: playlist.owner_id == user.id,
        # The Users it's shared with, the User last
        shared_with:
          playlist.accesses
          |> Enum.map(& &1.user)
          |> Enum.sort_by(&(&1.id == user.id))
      )

    ~H"""
    <section
      aria-labelledby="playlist-name"
      class="flex min-w-0 flex-col gap-cluster px-page pb-page-y md:pt-group"
    >
      <header class="flex flex-col gap-group @3xl:flex-row @3xl:items-start @3xl:justify-between">
        <div class="flex min-w-0 flex-col gap-related">
          <h2
            id="playlist-name"
            class="flex items-center gap-related font-heading text-2xl font-semibold @3xl:text-3xl"
          >
            <.lucide_icon name={@playlist.icon} class="size-icon-lg shrink-0 text-text-muted" />
            <span class="min-w-0 truncate">{@playlist.name}</span>
          </h2>
          <div class="flex flex-wrap items-center gap-x-group gap-y-related text-sm text-text-muted">
            <span :if={!@owner?} class="inline-flex items-center gap-tight">
              {raw(
                dgettext("playlists", "Created by %{user}",
                  user: gtcomponent(person(%{user: @playlist.owner}))
                )
              )}
            </span>
            <span :if={@shared_with == []} class="inline-flex items-center gap-tight">
              <Lucideicons.lock class="size-icon-sm text-text-subtle" aria-hidden="true" />
              {dgettext("playlists", "Private")}
            </span>
            <span :if={@shared_with != []} class="inline-flex items-center gap-tight">
              {dgettext("playlists", "Shared with")}
              <.tooltip id="shared-with">
                <:trigger>
                  <button
                    type="button"
                    aria-label={names(@shared_with, @current_user)}
                    class="rounded-full"
                  >
                    <.avatar_group
                      avatars={Enum.map(@shared_with, &%{id: &1.id, name: &1.username})}
                      avatar_size="sm"
                      avatar_class="ring-2 ring-canvas"
                      class="-space-x-1.5!"
                    />
                  </button>
                </:trigger>
                {names(@shared_with, @current_user)}
              </.tooltip>
            </span>
            <span :if={@playlist.movie_count + @playlist.tv_show_count > 0}>
              {content_counts(@playlist)}
            </span>
          </div>
        </div>
        <div :if={@owner?} class="flex shrink-0 gap-related">
          <.dropdown_menu id="playlist-actions">
            <:trigger>
              <.button
                id="playlist-actions-button"
                variant="secondary"
                size="icon"
                aria-label={
                  dgettext("playlists", "Actions for %{playlist}", playlist: @playlist.name)
                }
              >
                <Lucideicons.ellipsis />
              </.button>
            </:trigger>
            <.dropdown_menu_item id="edit-playlist" phx-click="edit_playlist">
              <Lucideicons.pencil /> {dgettext("playlists", "Edit playlist")}
            </.dropdown_menu_item>
            <.dropdown_menu_item
              id="delete-playlist"
              variant="destructive"
              phx-click="delete_playlist"
            >
              <Lucideicons.trash /> {dgettext("playlists", "Delete playlist")}
            </.dropdown_menu_item>
          </.dropdown_menu>
        </div>
      </header>

      <ul id="playlist-items" phx-update="stream" class="flex flex-col">
        <li id="playlist-items-empty" class="hidden only:block">
          <.empty>
            <:icon><Lucideicons.clapperboard /></:icon>
            <:title>{dgettext("playlists", "Nothing here yet")}</:title>
            <:description>
              {dgettext("playlists", "Add movies and TV shows from their page.")}
            </:description>
            <.button id="empty-browse" variant="secondary" navigate={~p"/"}>
              <:icon><Lucideicons.clapperboard /></:icon>
              {dgettext("nav", "Browse")}
            </.button>
          </.empty>
        </li>
        <.item_row
          :for={{dom_id, item} <- @items}
          id={dom_id}
          item={item}
          playlist={@playlist}
          current_user={@current_user}
        />
      </ul>
      <.infinite_scroll_trigger
        :if={KeysetStreamState.can_load_more?(@items_state)}
        id="playlist-items-load-more"
        event="load_more_items"
      />
    </section>
    """
  end

  attr :id, :string, required: true
  attr :item, PlaylistItem, required: true
  attr :playlist, Playlist, required: true
  attr :current_user, User, required: true

  # Its poster and name, which open the Content, who added it once the Playlist is shared, then
  # Play, Resume or Request, and a menu to remove it for the Users who can
  defp item_row(assigns) do
    %{item: %{content: content}} = assigns

    assigns =
      assign(assigns,
        content: content,
        identity: ContentIdentity.from_content(content),
        title: content.implementation.best_localization.title,
        progress: progress_percent(content)
      )

    ~H"""
    <li id={@id} class="flex items-center gap-group py-group">
      <.link navigate={Url.content_details_link(@identity)} class="shrink-0" tabindex="-1">
        <.tmdb_poster
          path={@content.implementation.best_localization.poster_path}
          size="w154"
          class={["w-20", !@content.has_media? && "opacity-60 grayscale"]}
        >
          <.progress_bar
            :if={@progress}
            percent={@progress}
            class="absolute inset-x-0 bottom-0 rounded-none!"
          />
        </.tmdb_poster>
      </.link>
      <div class="flex min-w-0 flex-1 flex-col gap-related">
        <div class="flex min-w-0 flex-col">
          <.link
            navigate={Url.content_details_link(@identity)}
            class="truncate text-lg font-semibold hover:underline"
          >
            {@title}
          </.link>
          <span class="truncate text-sm text-text-muted">
            {[Time.maybe_year(@content.release_date), ContentType.translated_label(@content.type)]
            |> Enum.filter(& &1)
            |> Enum.join(" · ")}
          </span>
          <span
            :if={@playlist.accesses != []}
            class="flex min-w-0 items-center gap-tight text-xs text-text-subtle"
          >
            <.avatar
              :if={@item.added_by}
              id={@item.added_by.id}
              name={@item.added_by.username}
              size="sm"
              aria-hidden="true"
            />
            <span class="truncate">{added_line(@item, @current_user.settings.locale)}</span>
          </span>
        </div>
        <div class="flex flex-wrap items-center gap-related">
          <.live_component
            id={PlayOrRequestButtonLive.dom_id(@identity)}
            module={PlayOrRequestButtonLive}
            content_identity={@identity}
            current_user={@current_user}
          />
        </div>
      </div>
      <.dropdown_menu :if={@playlist.editable_by?} id={"#{@id}-menu"}>
        <:trigger>
          <.button
            id={"#{@id}-menu-button"}
            variant="ghost"
            size="icon"
            aria-label={dgettext("playlists", "More for %{content}", content: @title)}
          >
            <Lucideicons.ellipsis_vertical />
          </.button>
        </:trigger>
        <.dropdown_menu_item
          id={"#{@id}-remove"}
          variant="destructive"
          phx-click="remove_item"
          phx-value-content_id={@content.id}
        >
          <Lucideicons.list_minus />
          {dgettext("playlists", "Remove from %{playlist}", playlist: @playlist.name)}
        </.dropdown_menu_item>
      </.dropdown_menu>
    </li>
    """
  end

  attr :user, User, required: true

  # A User in a sentence: their avatar and their name
  defp person(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-tight">
      <.avatar id={@user.id} name={@user.username} size="sm" aria-hidden="true" />
      <span class="font-semibold text-text">{@user.username}</span>
    </span>
    """
  end

  # "Added by leadelpeut, 3 days ago", without who once they're deleted
  defp added_line(%PlaylistItem{added_by: nil} = item, locale),
    do:
      dgettext("playlists", "Added %{time}", time: Time.relative_from_now(item.added_at, locale))

  defp added_line(item, locale) do
    dgettext("playlists", "Added by %{user}, %{time}",
      user: item.added_by.username,
      time: Time.relative_from_now(item.added_at, locale)
    )
  end

  # "guigui74, wercia20 and you"
  defp names(users, current_user) do
    users
    |> Enum.map(
      &if(&1.id == current_user.id, do: dgettext("playlists", "you"), else: &1.username)
    )
    |> WatchClub.Cldr.List.to_string!(
      locale: UserLocale.to_cldr_locale_name(current_user.settings.locale)
    )
  end

  # How much of it the User watched, while they're watching it
  defp progress_percent(%Content{actor_progress_status: :in_progress, type: :movie} = content),
    do: content.implementation.actor_progress.percent_watched

  defp progress_percent(%Content{actor_progress_status: :in_progress, type: :tv_show} = content),
    do: content.implementation.actor_percent_watched

  defp progress_percent(_content), do: nil

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     |> stream_configure(:items, dom_id: &"playlist-item-#{&1.content_id}")
     |> assign(
       shown_id: nil,
       items_state: KeysetStreamState.init(@items_page_size),
       playlist_form: nil,
       playlist_icon: nil,
       icon_picker_open?: false,
       deleting?: false
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = socket |> assign(:opened_id, params["playlist_id"]) |> load_playlists!()

    if opened_missing?(socket) do
      {:noreply,
       socket
       |> put_flash(
         :error,
         dgettext("playlists", "This playlist doesn't exist, or it isn't shared with you.")
       )
       |> push_patch(to: ~p"/playlists")}
    else
      {:noreply, show_playlist(socket)}
    end
  end

  @impl true
  def handle_event("load_more_items", _params, socket) do
    if KeysetStreamState.can_load_more?(socket.assigns.items_state),
      do: {:noreply, load_items_page(socket)},
      else: {:noreply, socket}
  end

  def handle_event("new_playlist", _params, socket) do
    form = Playlists.form_to_create_playlist(actor: socket.assigns.current_user)
    {:noreply, assign(socket, playlist_form: to_form(form), playlist_icon: "list")}
  end

  def handle_event("edit_playlist", _params, socket) do
    playlist = shown_playlist(socket)
    form = Playlists.form_to_update_playlist(playlist, actor: socket.assigns.current_user)
    {:noreply, assign(socket, playlist_form: to_form(form), playlist_icon: playlist.icon)}
  end

  def handle_event("validate_playlist", %{"form" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :playlist_form,
       AshPhoenix.Form.validate(socket.assigns.playlist_form, params)
     )}
  end

  def handle_event("save_playlist", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.playlist_form, params: params) do
      {:ok, playlist} ->
        {:noreply,
         socket
         |> assign(playlist_form: nil)
         |> push_patch(to: ~p"/playlists/#{playlist.id}")}

      {:error, form} ->
        {:noreply, assign(socket, :playlist_form, form)}
    end
  end

  def handle_event("close_playlist_form", _params, socket),
    do: {:noreply, assign(socket, playlist_form: nil, icon_picker_open?: false)}

  def handle_event("open_icon_picker", _params, socket),
    do: {:noreply, assign(socket, :icon_picker_open?, true)}

  def handle_event("close_icon_picker", _params, socket),
    do: {:noreply, assign(socket, :icon_picker_open?, false)}

  def handle_event("icon_selected", %{"icon" => icon}, socket),
    do: {:noreply, assign(socket, playlist_icon: icon, icon_picker_open?: false)}

  def handle_event("delete_playlist", _params, socket),
    do: {:noreply, assign(socket, :deleting?, true)}

  def handle_event("close_delete_playlist", _params, socket),
    do: {:noreply, assign(socket, :deleting?, false)}

  def handle_event("confirm_delete_playlist", _params, socket) do
    Playlists.destroy_playlist!(shown_playlist(socket), actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:deleting?, false)
     |> put_flash(:info, dgettext("playlists", "Playlist deleted."))
     |> push_patch(to: ~p"/playlists")}
  end

  def handle_event("remove_item", %{"content_id" => content_id}, socket) do
    %{shown_id: playlist_id, current_user: user} = socket.assigns

    %PlaylistItem{content: content} =
      Playlists.remove_from_playlist!(playlist_id, content_id,
        return_destroyed?: true,
        load: [content: [:implementation]],
        actor: user
      )

    {:noreply,
     put_flash(
       socket,
       :info,
       dgettext("playlists", "Removed %{content} from %{playlist}.",
         content: content.implementation.best_localization.title,
         playlist: shown_playlist(socket).name
       )
     )}
  end

  # A Playlist the User sees, or what it holds, changed. It may also be new to them, or gone.
  @impl true
  def handle_info(%Notification{resource: resource} = notification, socket)
      when resource in [Playlist, PlaylistAccess, PlaylistItem] do
    socket = load_playlists!(socket)

    if opened_missing?(socket) do
      {:noreply,
       socket
       |> put_flash(:info, gone_message(notification))
       |> push_patch(to: ~p"/playlists")}
    else
      {:noreply, socket |> show_playlist() |> update_items(notification)}
    end
  end

  # What a row shows of its Content changed: its poster, its progress, or whether it can be played
  def handle_info(%Notification{resource: resource} = notification, socket)
      when resource in [Content, Media, WatchProgress] do
    %{shown_id: playlist_id, current_user: user} = socket.assigns
    PlayOrRequestButtonLive.handle_pubsub_message(notification, user)

    content_id =
      case notification do
        %{data: %Content{id: id}} -> id
        %{metadata: %{content_id: id}} -> id
      end

    case playlist_id &&
           Playlists.get_playlist_item!(playlist_id, content_id,
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

  # Your playlists, and the ones shared with you, oldest first. Intentionally small: a User has
  # a handful of Playlists.
  defp load_playlists!(socket) do
    user = socket.assigns.current_user

    playlists =
      Playlists.list_playlists!(
        load: [
          :movie_count,
          :tv_show_count,
          :owner,
          accesses: [:user],
          editable_by?: %{user_id: user.id}
        ],
        actor: user
      )

    {mine, shared} = Enum.split_with(playlists, &(&1.owner_id == user.id))

    socket
    |> assign(mine: mine, shared: shared)
    |> WatchClub.PubSub.subscribe_to_playlists(playlists)
  end

  defp opened_missing?(%{assigns: %{opened_id: nil}}), do: false

  defp opened_missing?(%{assigns: %{opened_id: id, mine: mine, shared: shared}}),
    do: not Enum.any?(mine ++ shared, &(&1.id == id))

  defp shown_playlist(%{assigns: %{shown_id: id, mine: mine, shared: shared}}),
    do: Enum.find(mine ++ shared, &(&1.id == id))

  # The Playlist beside the list: the one opened, else the first. Its items load when it changes.
  defp show_playlist(socket) do
    %{opened_id: opened_id, mine: mine, shared: shared} = socket.assigns
    first = List.first(mine ++ shared)
    shown_id = opened_id || (first && first.id)

    if shown_id == socket.assigns.shown_id,
      do: socket,
      else: socket |> assign(:shown_id, shown_id) |> reset_items()
  end

  defp gone_message(%Notification{resource: Playlist, action: %{type: :destroy}}),
    do: dgettext("playlists", "This playlist was deleted.")

  defp gone_message(_notification),
    do: dgettext("playlists", "This playlist is no longer shared with you.")

  # A Playlist Item of the shown Playlist came or went. When the Playlist itself changes, its rows
  # reload: they show whether the User can remove them, and who added them once it's shared.
  defp update_items(
         %{assigns: %{shown_id: id}} = socket,
         %Notification{resource: PlaylistItem, action: %{type: :create}, data: %{playlist_id: id}} =
           notification
       ) do
    item = Ash.load!(notification.data, @item_load, actor: socket.assigns.current_user)
    stream_insert(socket, :items, item, at: 0)
  end

  defp update_items(
         %{assigns: %{shown_id: id}} = socket,
         %Notification{
           resource: PlaylistItem,
           action: %{type: :destroy},
           data: %{playlist_id: id}
         } =
           notification
       ),
       do: stream_delete(socket, :items, notification.data)

  defp update_items(
         %{assigns: %{shown_id: id}} = socket,
         %Notification{resource: Playlist, action: %{type: :update}, data: %{id: id}}
       ),
       do: reset_items(socket)

  defp update_items(socket, _notification), do: socket

  defp reset_items(socket) do
    socket
    |> assign(:items_state, KeysetStreamState.init(@items_page_size))
    |> load_items_page()
  end

  defp load_items_page(%{assigns: %{shown_id: nil}} = socket),
    do: stream(socket, :items, [], reset: true)

  defp load_items_page(socket) do
    %{items_state: state, shown_id: playlist_id, current_user: user} = socket.assigns

    {:ok, new_state, items} =
      KeysetStreamState.load_page(state, fn page ->
        Playlists.list_playlist_items(playlist_id, load: @item_load, page: page, actor: user)
      end)

    socket
    |> assign(:items_state, new_state)
    |> stream(:items, items, reset: state.status == :init)
  end
end
