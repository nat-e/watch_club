defmodule WatchClub.Media.ImportSourceType do
  @moduledoc """
  The kind of source a Media Import Configuration imports from.

  Only `:filesystem` is implemented today. External media servers and automation
  services are planned (see `CONTEXT.md`); they will be added here when supported.
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
