defmodule WatchClub.Contents.ExternalIdSource do
  use Ash.Type.Enum,
    values: [:tmdb, :hardcover]
end
