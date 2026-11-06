defmodule WatchClubWeb.Playlists.PlaylistsPage.SharePlaylistModal do
  @moduledoc """
  The dialog where the owner shares a Playlist: for each other User, no access, View or Edit
  Playlist Access, and what that gives.
  """
  use WatchClubWeb, :component

  attr :playlist, Playlist, required: true

  attr :users, :list,
    required: true,
    doc: "the other Users, intentionally small: the instance's Users"

  attr :levels, :map, required: true, doc: "the chosen `PlaylistAccessLevel` of each User's id"
  attr :locale, :atom, required: true, doc: "a `UserLocale`"

  def share_playlist_modal(assigns) do
    ~H"""
    <.modal id="share-playlist-modal" size="md" on_close={JS.push("close_share_playlist")}>
      <:title>{dgettext("playlists", "Share “%{playlist}”", playlist: @playlist.name)}</:title>
      <:description>
        {dgettext(
          "playlists",
          "They'll find it in their Playlists. Choose who can only view it and who can also edit it."
        )}
      </:description>

      <.form
        for={%{}}
        id="share-playlist-form"
        layout="none"
        phx-change="choose_playlist_access"
        class="-mx-related flex flex-col"
      >
        <div :for={user <- @users} class="flex items-center gap-related p-related">
          <.avatar id={user.id} name={user.username} aria-hidden="true" />
          <span class="min-w-0 flex-1 truncate text-sm font-semibold">{user.username}</span>
          <.select
            id={"share-#{user.id}"}
            name={"levels[#{user.id}]"}
            value={Map.get(@levels, user.id, "none")}
            aria-label={dgettext("playlists", "Access for %{user}", user: user.username)}
            class="w-36 shrink-0"
          >
            <.select_item value="none">{dgettext("playlists", "No access")}</.select_item>
            <.select_item value="view">{dgettext("playlists", "Can view")}</.select_item>
            <.select_item value="edit">{dgettext("playlists", "Can edit")}</.select_item>
          </.select>
        </div>
      </.form>

      <p class="flex items-center gap-related text-sm text-text-muted">
        <Lucideicons.lock
          :if={@levels == %{}}
          class="size-icon-sm shrink-0 text-text-subtle"
          aria-hidden="true"
        />
        <Lucideicons.users
          :if={@levels != %{}}
          class="size-icon-sm shrink-0 text-text-subtle"
          aria-hidden="true"
        />
        {if @levels == %{},
          do: dgettext("playlists", "Private: only you can see it."),
          else: who_can(@users, @levels, @locale)}
      </p>

      <:footer>
        <.button id="share-playlist-cancel" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button id="share-playlist-save" phx-click="save_playlist_access">
          {dgettext("default", "Save")}
        </.button>
      </:footer>
    </.modal>
    """
  end

  # "leadelpeut can edit. guigui74 and vinz can view."
  defp who_can(users, levels, locale) do
    editors = for user <- users, levels[user.id] == "edit", do: user.username
    viewers = for user <- users, levels[user.id] == "view", do: user.username

    [
      editors != [] &&
        dngettext("playlists", "%{users} can edit.", "%{users} can edit.", length(editors),
          users: list(editors, locale)
        ),
      viewers != [] &&
        dngettext("playlists", "%{users} can view.", "%{users} can view.", length(viewers),
          users: list(viewers, locale)
        )
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end

  defp list(names, locale),
    do: WatchClub.Cldr.List.to_string!(names, locale: UserLocale.to_cldr_locale_name(locale))
end
