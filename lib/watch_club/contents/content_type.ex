defmodule WatchClub.Contents.ContentType do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      book: [description: "A book", label: "Books"],
      movie: [description: "A movie", label: "Movies"],
      # podcast: [description: "A podcast", label: "Podcasts"],
      tv_show: [description: "A TV show or anime", label: "TV Shows"]
    ]

  def translated_label(:book), do: dgettext("content_types", "Book")
  def translated_label(:movie), do: dgettext("content_types", "Movie")
  def translated_label(:tv_show), do: dgettext("content_types", "TV Show")
end
