defmodule WatchClub.Media.ImportSourceType do
  @moduledoc """
  The kind of source a Media Import Configuration imports from.
  """

  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      filesystem: [
        description: "Imports Media by scanning a filesystem directory",
        label: "Filesystem"
      ]
    ]

  def translated_label(:filesystem), do: dgettext("import_source_types", "Filesystem")
end
