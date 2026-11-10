defmodule WatchClub.Contents.SearchResult do
  @moduledoc """
  A Movie, TV Show or Sports Event found by a search, and whether it's in the Library.
  `poster_path` is a TMDB path, or an image URL for a Sports Event.
  """
  alias WatchClub.Contents.ContentIdentity

  @type t :: %__MODULE__{
          identity: ContentIdentity.t(),
          title: String.t(),
          year: pos_integer() | nil,
          overview: String.t() | nil,
          poster_path: String.t() | nil,
          has_media?: boolean()
        }

  defstruct [:identity, :title, :year, :overview, :poster_path, has_media?: false]
end
