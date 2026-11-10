defmodule WatchClub.MediaCatalog.MediaType do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      movie: [description: "Video file for a Movie"],
      tv_show_episode: [description: "Video file for a TV Show Episode"],
      sports_event: [description: "Video file for a Sports Event"],
      ebook: [description: "Ebook file"],
      audiobook: [description: "Audiobook file"]
    ]

  def translated_label(:movie), do: dgettext("media_types", "Movie")
  def translated_label(:tv_show_episode), do: dgettext("media_types", "TV Show Episode")
  def translated_label(:sports_event), do: dgettext("media_types", "Sports Event")
  def translated_label(:ebook), do: dgettext("media_types", "Ebook")
  def translated_label(:audiobook), do: dgettext("media_types", "Audiobook")

  def translated_plural_label(:movie), do: dgettext("media_types", "Movies")
  def translated_plural_label(:tv_show_episode), do: dgettext("media_types", "TV Shows")
  def translated_plural_label(:sports_event), do: dgettext("media_types", "Sports")
  def translated_plural_label(:ebook), do: dgettext("media_types", "Ebooks")
  def translated_plural_label(:audiobook), do: dgettext("media_types", "Audiobooks")
end
