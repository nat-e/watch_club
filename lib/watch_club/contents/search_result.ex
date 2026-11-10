defmodule WatchClub.Contents.SearchResult do
  @moduledoc """
  A Movie, TV Show or Sports Event found by a search, and whether it's in the Library.
  `poster_path` is a TMDB path, or an image URL for a Sports Event.
  """
  alias WatchClub.Contents.{Content, ContentIdentity}

  @type t :: %__MODULE__{
          identity: ContentIdentity.t(),
          title: String.t(),
          year: pos_integer() | nil,
          overview: String.t() | nil,
          poster_path: String.t() | nil,
          has_media?: boolean()
        }

  defstruct [:identity, :title, :year, :overview, :poster_path, has_media?: false]

  @doc """
  A Content of the Library as a search result, with its `implementation`'s `best_localization`
  loaded.
  """
  def from_content(%Content{} = content) do
    localization = content.implementation.best_localization

    %__MODULE__{
      identity: ContentIdentity.from_content(content),
      title: localization.title,
      year: content.release_date && content.release_date.year,
      overview: localization.overview,
      poster_path: localization.poster_path,
      has_media?: true
    }
  end
end
