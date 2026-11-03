defmodule WatchClub.Contents.SearchResult do
  @moduledoc """
  A Movie or TV Show found by a search, with the actor's clubs whose libraries already have it.
  """
  alias WatchClub.Clubs.Club
  alias WatchClub.Contents.ContentIdentity

  @type t :: %__MODULE__{
          identity: ContentIdentity.t(),
          title: String.t(),
          year: pos_integer() | nil,
          overview: String.t() | nil,
          poster_path: String.t() | nil,
          clubs: [Club.t()]
        }

  defstruct [:identity, :title, :year, :overview, :poster_path, clubs: []]
end
