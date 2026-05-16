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
end
