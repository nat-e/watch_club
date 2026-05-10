defmodule WatchClub.Contents.SearchContentType do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      movies_and_shows: [label: "Movies and Shows"],
      books: [label: "Books"]
    ]

  def translated_label(:movies_and_shows), do: dgettext("content_types", "Movies and Shows")
  def translated_label(:books), do: dgettext("content_types", "Books")
end
