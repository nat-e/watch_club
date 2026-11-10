defmodule WatchClub.MediaSources.Source.Type do
  @moduledoc """
  The kind of upstream system a `Media Source` represents.

  A `Source.Type` also determines whether the Media Source accepts
  `Media Source Requests`. Today `filesystem` does not; `radarr`,
  `sonarr` and `sportarr` do.
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
      ],
      sonarr: [
        description:
          "Imports Media from a Sonarr server and asks it to fetch new TV Shows on request",
        label: "Sonarr"
      ],
      sportarr: [
        description:
          "Imports Media from a Sportarr server and asks it to fetch new Sports Events on request",
        label: "Sportarr"
      ]
    ]

  def translated_label(:filesystem), do: dgettext("media_source_types", "Filesystem")
  def translated_label(:radarr), do: dgettext("media_source_types", "Radarr")
  def translated_label(:sonarr), do: dgettext("media_source_types", "Sonarr")
  def translated_label(:sportarr), do: dgettext("media_source_types", "Sportarr")
end
