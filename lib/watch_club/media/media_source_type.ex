defmodule WatchClub.Media.MediaSourceType do
  @moduledoc """
  The kind of upstream system a `Media Source` represents.
  """

  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      filesystem: [
        description: "Imports Media by scanning a filesystem directory",
        label: "Filesystem"
      ]
    ]

  def translated_label(:filesystem), do: dgettext("media_source_types", "Filesystem")
end
