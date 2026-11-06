defmodule WatchClubWeb.Playlists.PlaylistsPage.PlaylistDetail do
  @moduledoc """
  The open Playlist: its name, who has it and what it holds, its owner's actions, then its
  Playlist Items, each with Play, Resume or Request.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Playlists.PlaylistLink, only: [content_counts: 1]

  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive
  alias WatchClubWeb.Helpers.KeysetStreamState
  alias WatchClubWeb.Playlists.PlaylistsPage.PlaylistDialogsLive

  attr :playlist, Playlist,
    required: true,
    doc: "with its `owner`, the `user` of its `accesses`, its counts and `editable_by?` the User"

  attr :items, :any, required: true, doc: "the stream of its Playlist Items"
  attr :items_state, KeysetStreamState, required: true
  attr :current_user, User, required: true

  def playlist_detail(assigns) do
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
            class="flex items-start gap-related font-heading text-2xl font-semibold @3xl:text-3xl"
          >
            <%!-- As tall as a line, so the icon stays beside the first one when the name wraps --%>
            <span class="flex h-[1lh] shrink-0 items-center">
              <.lucide_icon name={@playlist.icon} class="size-icon-lg text-text-muted" />
            </span>
            <span class="min-w-0 break-words">{@playlist.name}</span>
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
                    aria-label={Usernames.join(@shared_with, @current_user)}
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
                {Usernames.join(@shared_with, @current_user)}
              </.tooltip>
            </span>
            <span :if={@playlist.movie_count + @playlist.tv_show_count > 0}>
              {content_counts(@playlist)}
            </span>
          </div>
        </div>
        <div :if={@owner?} class="flex shrink-0 gap-related">
          <.button
            id="share-playlist"
            variant="secondary"
            phx-click={PlaylistDialogsLive.open(:share)}
          >
            <:icon><Lucideicons.user_plus /></:icon>
            {dgettext("playlists", "Share")}
          </.button>
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
            <.dropdown_menu_item id="edit-playlist" phx-click={PlaylistDialogsLive.open(:edit)}>
              <Lucideicons.pencil /> {dgettext("playlists", "Edit playlist")}
            </.dropdown_menu_item>
            <.dropdown_menu_item
              id="delete-playlist"
              variant="destructive"
              phx-click={PlaylistDialogsLive.open(:delete)}
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

  # Its poster and name, which open the Content, then Play, Resume or Request, who added it once
  # the Playlist is shared, and a menu to Get Notified while it's on its way, or to remove it for
  # the Users who can. They spread over the poster's height: what it is at its top, the last of
  # them at its bottom.
  defp item_row(assigns) do
    %{item: %{content: content}} = assigns

    assigns =
      assign(assigns,
        content: content,
        identity: ContentIdentity.from_content(content),
        title: content.implementation.best_localization.title,
        progress: progress_percent(content),
        # Someone requested it, it isn't ready yet, and the User isn't told when it will be
        get_notified?:
          !content.has_media? and content.request != nil and
            !content.request.actor_subscriber?
      )

    ~H"""
    <li id={@id} class="flex items-start gap-group py-group">
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
      <div class="flex min-w-0 flex-1 flex-col justify-between gap-related self-stretch">
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
        </div>
        <div class="flex flex-wrap items-center gap-related">
          <.live_component
            id={PlayOrRequestButtonLive.dom_id(@identity)}
            module={PlayOrRequestButtonLive}
            content_identity={@identity}
            current_user={@current_user}
            get_notified={false}
          />
        </div>
        <span
          :if={@playlist.accesses != [] and @item.added_by}
          class="flex min-w-0 items-center gap-tight text-xs text-text-subtle"
        >
          <.avatar
            id={@item.added_by.id}
            name={@item.added_by.username}
            size="xs"
            aria-hidden="true"
          />
          <span class="truncate">
            {dgettext("playlists", "Added by %{user}", user: @item.added_by.username)}
          </span>
        </span>
      </div>
      <%!-- As tall as the name's line, so the menu is centered on it --%>
      <div
        :if={@playlist.editable_by? or @get_notified?}
        class="flex h-[1lh] shrink-0 items-center text-lg"
      >
        <.dropdown_menu id={"#{@id}-menu"}>
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
            :if={@get_notified?}
            id={"#{@id}-get-notified"}
            phx-click="get_notified"
            phx-value-content_request_id={@content.request.id}
          >
            <Lucideicons.bell /> {dgettext("playlists", "Get notified when ready")}
          </.dropdown_menu_item>
          <.dropdown_menu_item
            :if={@playlist.editable_by?}
            id={"#{@id}-remove"}
            variant="destructive"
            phx-click="remove_item"
            phx-value-content_id={@content.id}
          >
            <Lucideicons.list_minus />
            {dgettext("playlists", "Remove from %{playlist}", playlist: @playlist.name)}
          </.dropdown_menu_item>
        </.dropdown_menu>
      </div>
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

  # How much of it the User watched, while they're watching it
  defp progress_percent(%Content{actor_progress_status: :in_progress, type: :movie} = content),
    do: content.implementation.actor_progress.percent_watched

  defp progress_percent(%Content{actor_progress_status: :in_progress, type: :tv_show} = content),
    do: content.implementation.actor_percent_watched

  defp progress_percent(_content), do: nil
end
