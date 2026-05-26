defmodule WatchClubWeb.Components.Medias.LibraryLists do
  @moduledoc """
  Renderings of the libraries (and their clubs) that hold a `Media`.

  Three layouts share the same underlying aggregation over the media's
  `library_items`:

  - `media_clubs_avatars/1` — compact avatar group of unique clubs.
  - `media_libraries_chips/1` — horizontal chips of avatar + library name with
    a `+N` overflow when more than `:max` libraries are present.
  - `media_libraries_list/1` — vertical avatar + library name list with no
    truncation.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.UI.Avatar

  alias WatchClub.Media.{Audiobook, Ebook, Media, Video}

  attr :media, Media, required: true

  def media_clubs_avatars(assigns) do
    assigns = assign(assigns, :clubs, clubs(assigns.media))

    ~H"""
    <span :if={@clubs == []} class="text-xs text-text-subtle">—</span>
    <.avatar_group :if={@clubs != []} avatars={@clubs} avatar_size="sm" />
    """
  end

  attr :media, Media, required: true
  attr :max, :integer, default: 3

  def media_libraries_chips(assigns) do
    libraries = libraries(assigns.media)
    visible = Enum.take(libraries, assigns.max)
    overflow = length(libraries) - length(visible)

    assigns =
      assigns
      |> assign(:visible, visible)
      |> assign(:overflow, overflow)

    ~H"""
    <ul :if={@visible != []} class="flex flex-wrap items-center gap-related">
      <li
        :for={library <- @visible}
        class="flex items-center gap-tight min-w-0 text-sm text-text-subtle"
      >
        <.avatar id={library.club.id} name={library.club.name} />
        <span class="truncate">{library.name}</span>
      </li>
      <li :if={@overflow > 0} class="text-sm text-text-subtle">
        +{@overflow}
      </li>
    </ul>
    """
  end

  attr :media, Media, required: true

  def media_libraries_list(assigns) do
    assigns = assign(assigns, :libraries, libraries(assigns.media))

    ~H"""
    <p :if={@libraries == []} class="text-base text-text-subtle">
      This content is not in any Library.
    </p>
    <ul :if={@libraries != []} class="grid gap-related">
      <li
        :for={library <- @libraries}
        class="flex items-center gap-related text-base text-text"
      >
        <.avatar id={library.club.id} name={library.club.name} size="sm" />
        <span class="min-w-0 truncate">{library.name}</span>
      </li>
    </ul>
    """
  end

  defp clubs(media) do
    media
    |> library_items()
    |> Enum.map(fn item -> item.library.club end)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.name)
  end

  defp libraries(media) do
    media
    |> library_items()
    |> Enum.map(fn item ->
      %{id: item.library.id, name: item.library.name, club: item.library.club}
    end)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(&{&1.club.name, &1.name})
  end

  defp library_items(%Media{type: :movie, video: %Video{movie: %{content: %{library_items: items}}}})
       when is_list(items),
       do: items

  defp library_items(%Media{
         type: :tv_show_episode,
         video: %Video{tv_show_episode: %{tv_show: %{content: %{library_items: items}}}}
       })
       when is_list(items),
       do: items

  defp library_items(%Media{type: :ebook, ebook: %Ebook{book: %{content: %{library_items: items}}}})
       when is_list(items),
       do: items

  defp library_items(%Media{
         type: :audiobook,
         audiobook: %Audiobook{book: %{content: %{library_items: items}}}
       })
       when is_list(items),
       do: items

  defp library_items(_), do: []
end
