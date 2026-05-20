defmodule WatchClub.Media.MediaImportResultStatus do
  use Ash.Type.Enum,
    values: [
      created: [description: "A Media was created for the file", label: "Created"],
      updated: [description: "A Media already existed for the file", label: "Updated"],
      deleted: [description: "The file was missing and a Media was deleted", label: "Deleted"],
      no_match: [
        description: "Could not match the file metadata to a Content",
        label: "No Match"
      ],
      failed: [description: "There was an error processing this file", label: "Failed"]
    ]
end
