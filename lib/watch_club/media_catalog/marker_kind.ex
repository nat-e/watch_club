defmodule WatchClub.MediaCatalog.MarkerKind do
  @moduledoc false

  use Ash.Type.Enum,
    values: [
      intro: [description: "Opening sequence the episodes of a TV Show share"],
      recap: [description: "Summary of earlier episodes"],
      credits: [description: "List of names at the end of the Video"]
    ]
end
