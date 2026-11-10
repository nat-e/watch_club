defmodule WatchClub.MediaSources.FilesToProcess do
  @moduledoc "Which files a Media Import processes. Processing a file reads it and matches it again."

  use Ash.Type.Enum,
    values: [
      new: [description: "Only the files without Media yet"],
      new_and_unmatched: [description: "The files without Media yet, and the Unmatched Media"],
      all: [description: "Every file, keeping the Manual Matches"]
    ]
end
