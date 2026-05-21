defmodule WatchClub.Media.ImportSourceType do
  use Ash.Type.Enum,
    values: [
      filesystem: [
        description: "A source that imports Media by scanning a filesystem directory.",
        label: "Filesystem"
      ]
    ]
end
