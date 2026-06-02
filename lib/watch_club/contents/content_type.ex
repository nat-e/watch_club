defmodule WatchClub.Contents.ContentType do
  use Gettext, backend: WatchClubWeb.Gettext

  @library_display_order [:movie, :tv_show, :book]

  use Ash.Type.Enum,
    values: [
      book: [description: "A book", label: "Books"],
      movie: [description: "A movie", label: "Movies"],
      # podcast: [description: "A podcast", label: "Podcasts"],
      tv_show: [description: "A TV show or anime", label: "TV Shows"]
    ]

  def library_display_order, do: @library_display_order

  def translated_label(:book), do: dgettext("content_types", "Book")
  def translated_label(:movie), do: dgettext("content_types", "Movie")
  def translated_label(:tv_show), do: dgettext("content_types", "TV Show")

  def translated_plural_label(:book), do: dgettext("content_types", "Books")
  def translated_plural_label(:movie), do: dgettext("content_types", "Movies")
  def translated_plural_label(:tv_show), do: dgettext("content_types", "TV Shows")

  @doc """
  The `MediaCatalog.MediaType`s that can serve this Content Type — the media
  kinds a Media Source produces for it. A book is served by both an ebook
  and an audiobook source, so this returns a list.
  """
  @spec media_types(t()) :: [atom()]
  def media_types(:movie), do: [:movie]
  def media_types(:tv_show), do: [:tv_show_episode]
  def media_types(:book), do: [:ebook, :audiobook]
end
