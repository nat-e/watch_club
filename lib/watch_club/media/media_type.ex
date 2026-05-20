defmodule WatchClub.Media.MediaType do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      video: [description: "A video file", label: "Video"],
      ebook: [description: "An ebook file", label: "Ebook"],
      audiobook: [description: "An audiobook file", label: "Audiobook"]
    ]

  def translated_label(:video), do: dgettext("media_types", "Video")
  def translated_label(:ebook), do: dgettext("media_types", "Ebook")
  def translated_label(:audiobook), do: dgettext("media_types", "Audiobook")
end
