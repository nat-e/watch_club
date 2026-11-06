defmodule WatchClubWeb.Contents.ContentPage.AddToPlaylistModal do
  @moduledoc """
  Add to Playlist: puts the Content in the User's Playlists and the shared ones they can edit, or
  takes it out, one checkbox each, or starts a new Playlist with it.
  """
  use WatchClubWeb, :component

  attr :title, :string, required: true, doc: "the Content's name"

  attr :playlists, :list,
    required: true,
    doc:
      "the Playlists the User can edit, with `holds_content?`, its `owner` and the `user` of its `accesses`"

  attr :new_playlist_form, Phoenix.HTML.Form, required: true
  attr :current_user, User, required: true

  def add_to_playlist_modal(assigns) do
    ~H"""
    <.modal id="add-to-playlist-modal" size="md" on_close={JS.push("close_add_to_playlist")}>
      <:title>{dgettext("playlists", "Add %{content} to a playlist", content: @title)}</:title>
      <:description>
        {dgettext("playlists", "Your playlists, and the shared playlists you can edit.")}
      </:description>

      <ul class="-mx-related flex flex-col">
        <li :for={playlist <- @playlists}>
          <label
            for={"in-playlist-#{playlist.id}"}
            class="flex cursor-pointer items-center gap-related rounded-control p-related transition-colors hover:bg-surface-hover"
          >
            <span class="grid size-control-sm shrink-0 place-items-center rounded-control bg-surface-raised text-text-muted">
              <.lucide_icon name={playlist.icon} class="size-icon-sm" />
            </span>
            <span class="flex min-w-0 flex-1 flex-col">
              <span class="truncate text-sm font-semibold">{playlist.name}</span>
              <span class="truncate text-xs text-text-muted">
                {sharing_line(playlist, @current_user)}
              </span>
            </span>
            <.checkbox
              id={"in-playlist-#{playlist.id}"}
              checked={playlist.holds_content?}
              phx-click="toggle_in_playlist"
              phx-value-playlist_id={playlist.id}
            />
          </label>
        </li>
      </ul>

      <.form
        for={@new_playlist_form}
        id="new-playlist-form"
        layout="none"
        phx-change="validate_new_playlist"
        phx-submit="create_playlist_with_content"
        class="flex flex-col gap-related"
      >
        <input type="hidden" name={@new_playlist_form[:icon].name} value="list" />
        <.label field={@new_playlist_form[:name]} class="sr-only">
          {dgettext("playlists", "New playlist")}
        </.label>
        <div class="flex items-center gap-related">
          <.input
            field={@new_playlist_form[:name]}
            class="flex-1"
            autocomplete="off"
            phx-debounce="blur"
            placeholder={dgettext("playlists", "New playlist")}
          />
          <.button id="new-playlist-create" type="submit" variant="secondary">
            {dgettext("default", "Create")}
          </.button>
        </div>
        <.field_errors field={@new_playlist_form[:name]} />
      </.form>

      <:footer>
        <.button id="add-to-playlist-done" data-modal-close>{dgettext("playlists", "Done")}</.button>
      </:footer>
    </.modal>
    """
  end

  # "Private", "Shared with leadelpeut", "vinz's playlist"
  defp sharing_line(%Playlist{owner_id: owner_id, accesses: []}, %User{id: owner_id}),
    do: dgettext("playlists", "Private")

  defp sharing_line(%Playlist{owner_id: owner_id} = playlist, %User{id: owner_id} = user) do
    dgettext("playlists", "Shared with %{users}",
      users: Usernames.join(Enum.map(playlist.accesses, & &1.user), user)
    )
  end

  defp sharing_line(playlist, _current_user),
    do: dgettext("playlists", "%{user}'s playlist", user: playlist.owner.username)
end
