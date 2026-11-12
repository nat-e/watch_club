defmodule WatchClubWeb.Playlists.PlaylistsPage.PlaylistDialogs.SharePlaylistModal do
  @moduledoc """
  The dialog where the owner shares a Playlist: for each other User, no access, View or Edit
  Playlist Access, and what that gives. Owner-private to `PlaylistDialogsLive`, which handles its
  events.
  """
  use WatchClubWeb, :component

  attr :playlist, Playlist, required: true

  attr :users, :list,
    required: true,
    doc: "the other Users, intentionally small: the instance's Users"

  attr :levels, :map, required: true, doc: "the chosen `PlaylistAccessLevel` of each User's id"
  attr :current_user, User, required: true
  attr :myself, :any, required: true

  def share_playlist_modal(assigns) do
    ~H"""
    <.modal id="share-playlist-modal" size="md" on_close={JS.push("close", target: @myself)}>
      <:title>{dgettext("playlists", "Share “%{playlist}”", playlist: @playlist.name)}</:title>
      <:description>
        {dgettext(
          "playlists",
          "They'll find it in their Playlists. Choose who can only view it, and who can also add and remove content."
        )}
      </:description>

      <.form
        for={%{}}
        id="share-playlist-form"
        layout="none"
        phx-change="choose_access"
        phx-target={@myself}
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

      <:footer>
        <.button id="share-playlist-cancel" type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button id="share-playlist-save" phx-click="save_access" phx-target={@myself}>
          {dgettext("default", "Save")}
        </.button>
        <%!-- In the footer, so it stays in view while the Users scroll: on top on phones, on the
        left from small screens --%>
        <p
          id="share-playlist-summary"
          class="flex items-center gap-related text-sm text-text-muted sm:order-first sm:mr-auto"
        >
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
            else: who_can(@users, @levels, @current_user)}
        </p>
      </:footer>
    </.modal>
    """
  end

  # "leadelpeut can edit. guigui74 and vinz can view."
  defp who_can(users, levels, current_user) do
    editors = Enum.filter(users, &(levels[&1.id] == "edit"))
    viewers = Enum.filter(users, &(levels[&1.id] == "view"))

    [
      editors != [] &&
        dngettext("playlists", "%{users} can edit.", "%{users} can edit.", length(editors),
          users: Usernames.join(editors, current_user)
        ),
      viewers != [] &&
        dngettext("playlists", "%{users} can view.", "%{users} can view.", length(viewers),
          users: Usernames.join(viewers, current_user)
        )
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end
end
