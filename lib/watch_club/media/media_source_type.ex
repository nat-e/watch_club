defmodule WatchClub.Media.MediaSourceType do
  @moduledoc """
  The kind of upstream system a `Media Source` represents.

  A `MediaSourceType` also determines whether the Media Source accepts
  `Media Source Requests`. Today `filesystem` does not; `radarr` does.
  """

  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      filesystem: [
        description: "Imports Media by scanning a filesystem directory",
        label: "Filesystem"
      ],
      radarr: [
        description:
          "Imports Media from a Radarr server and asks it to fetch new Movies on request",
        label: "Radarr"
      ]
    ]

  def translated_label(:filesystem), do: dgettext("media_source_types", "Filesystem")
  def translated_label(:radarr), do: dgettext("media_source_types", "Radarr")
end
