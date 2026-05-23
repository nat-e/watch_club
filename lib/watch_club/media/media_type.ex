defmodule WatchClub.Media.MediaType do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      movie: [description: "Video file for a Movie"],
      tv_show_episode: [description: "Video file for a TV Show Episode"],
      ebook: [description: "Ebook file"],
      audiobook: [description: "Audiobook file"]
    ]

  def translated_label(:movie), do: dgettext("media_types", "Movie")
  def translated_label(:tv_show_episode), do: dgettext("media_types", "TV Show Episode")
  def translated_label(:ebook), do: dgettext("media_types", "Ebook")
  def translated_label(:audiobook), do: dgettext("media_types", "Audiobook")
end
