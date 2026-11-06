defmodule WatchClubWeb.Components.Playlists.PlaylistLink do
  @moduledoc """
  A Playlist in a list, on the Playlists page and on a Content page: its icon, its name, what it
  holds, and whether it's private or who else has it.
  """
  use WatchClubWeb, :component

  attr :playlist, Playlist,
    required: true,
    doc: "with its `owner`, the `user` of its `accesses`, and its counts"

  attr :current_user, User, required: true
  attr :patch, :string, default: nil
  attr :navigate, :string, default: nil
  attr :selected, :boolean, default: false, doc: "the Playlist shown beside the list"

  attr :opened, :boolean,
    default: true,
    doc:
      "false while Playlists shows its first Playlist without one being opened: narrow screens then show only the list, so none is selected"

  def playlist_link(assigns) do
    assigns = assign(assigns, :others, others(assigns.playlist, assigns.current_user))

    ~H"""
    <.link
      id={"playlist-#{@playlist.id}"}
      patch={@patch}
      navigate={@navigate}
      aria-current={@selected && "true"}
      class={[
        "flex min-h-touch-target items-center gap-related rounded-control p-related transition-colors hover:bg-surface-hover",
        @opened && "aria-[current=true]:bg-surface-selected",
        !@opened && "@4xl:aria-[current=true]:bg-surface-selected"
      ]}
    >
      <span class="grid size-control-sm shrink-0 place-items-center rounded-control bg-surface-raised text-text-muted">
        <.lucide_icon name={@playlist.icon} class="size-icon-sm" />
      </span>
      <span class="flex min-w-0 flex-1 flex-col">
        <span class="truncate text-sm font-semibold">{@playlist.name}</span>
        <span class="truncate text-xs text-text-muted">{content_counts(@playlist)}</span>
      </span>
      <span :if={@others == []} class="shrink-0">
        <Lucideicons.lock class="size-icon-sm text-text-subtle" aria-hidden="true" />
        <span class="sr-only">{dgettext("playlists", "Private")}</span>
      </span>
      <.avatar_group
        :if={@others != []}
        avatars={Enum.map(@others, &%{id: &1.id, name: &1.username})}
        avatar_size="sm"
        avatar_class="ring-2 ring-canvas"
        class="shrink-0 -space-x-1.5!"
      />
    </.link>
    """
  end

  @doc """
  How many Movies and TV Shows a Playlist with its counts holds: "2 movies · 1 TV show", or
  "Empty".
  """
  def content_counts(%Playlist{movie_count: 0, tv_show_count: 0}),
    do: dgettext("playlists", "Empty")

  def content_counts(%Playlist{} = playlist) do
    [
      playlist.movie_count > 0 &&
        dngettext("playlists", "%{count} movie", "%{count} movies", playlist.movie_count),
      playlist.tv_show_count > 0 &&
        dngettext("playlists", "%{count} TV show", "%{count} TV shows", playlist.tv_show_count)
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  # Everyone who has the Playlist but the User: its owner, then the Users it's shared with
  defp others(playlist, current_user) do
    Enum.reject(
      [playlist.owner | Enum.map(playlist.accesses, & &1.user)],
      &(&1.id == current_user.id)
    )
  end
end
