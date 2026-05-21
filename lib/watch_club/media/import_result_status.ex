defmodule WatchClub.Media.ImportResultStatus do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      created: [description: "Media was created from the file", label: "Created"],
      updated: [description: "Media was rematched and refreshed from the file", label: "Updated"],
      deleted: [description: "Media was deleted because the file is missing", label: "Deleted"],
      no_match: [
        description: "File could not be matched to Content",
        label: "No Match"
      ],
      failed: [description: "File could not be processed", label: "Failed"]
    ]

  def translated_label(:created), do: dgettext("import_result_statuses", "Created")
  def translated_label(:updated), do: dgettext("import_result_statuses", "Updated")
  def translated_label(:deleted), do: dgettext("import_result_statuses", "Deleted")
  def translated_label(:no_match), do: dgettext("import_result_statuses", "No Match")
  def translated_label(:failed), do: dgettext("import_result_statuses", "Failed")
end
