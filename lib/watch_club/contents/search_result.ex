defmodule WatchClub.Contents.SearchResult do
  @moduledoc """
  A Movie or TV Show found by a search, and whether it's in the Library.
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
