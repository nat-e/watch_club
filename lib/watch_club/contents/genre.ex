defmodule WatchClub.Contents.Genre do
  @moduledoc """
  The kinds of story a Movie or TV Show tells, such as Drama or Comedy, from TMDB's genres.
  Movies and TV Shows share them: TMDB's TV genres that combine two, such as Action & Adventure,
  give both.
  """
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      :action,
      :adventure,
      :animation,
      :comedy,
      :crime,
      :documentary,
      :drama,
      :family,
      :fantasy,
      :history,
      :horror,
      :kids,
      :music,
      :mystery,
      :news,
      :politics,
      :reality,
      :romance,
      :science_fiction,
      :soap,
      :talk,
      :thriller,
      :tv_movie,
      :war,
      :western
    ]

  alias WatchClub.Integrations.Tmdb.Types

  # By TMDB genre id, from https://developer.themoviedb.org/reference/genre-movie-list and
  # https://developer.themoviedb.org/reference/genre-tv-list
  @by_tmdb_id %{
    28 => [:action],
    12 => [:adventure],
    16 => [:animation],
    35 => [:comedy],
    80 => [:crime],
    99 => [:documentary],
    18 => [:drama],
    10_751 => [:family],
    14 => [:fantasy],
    36 => [:history],
    27 => [:horror],
    10_402 => [:music],
    9648 => [:mystery],
    10_749 => [:romance],
    878 => [:science_fiction],
    10_770 => [:tv_movie],
    53 => [:thriller],
    10_752 => [:war],
    37 => [:western],
    # TV only
    10_759 => [:action, :adventure],
    10_762 => [:kids],
    10_763 => [:news],
    10_764 => [:reality],
    10_765 => [:science_fiction, :fantasy],
    10_766 => [:soap],
    10_767 => [:talk],
    10_768 => [:war, :politics]
  }

  @doc "The genres TMDB gives a Movie or TV Show, without the ones TMDB added after this list"
  @spec from_tmdb([Types.Genre.t()]) :: [t()]
  def from_tmdb(tmdb_genres) do
    tmdb_genres |> Enum.flat_map(&Map.get(@by_tmdb_id, &1.id, [])) |> Enum.uniq()
  end

  def translated_label(:action), do: dgettext("genres", "Action")
  def translated_label(:adventure), do: dgettext("genres", "Adventure")
  def translated_label(:animation), do: dgettext("genres", "Animation")
  def translated_label(:comedy), do: dgettext("genres", "Comedy")
  def translated_label(:crime), do: dgettext("genres", "Crime")
  def translated_label(:documentary), do: dgettext("genres", "Documentary")
  def translated_label(:drama), do: dgettext("genres", "Drama")
  def translated_label(:family), do: dgettext("genres", "Family")
  def translated_label(:fantasy), do: dgettext("genres", "Fantasy")
  def translated_label(:history), do: dgettext("genres", "History")
  def translated_label(:horror), do: dgettext("genres", "Horror")
  def translated_label(:kids), do: dgettext("genres", "Kids")
  def translated_label(:music), do: dgettext("genres", "Music")
  def translated_label(:mystery), do: dgettext("genres", "Mystery")
  def translated_label(:news), do: dgettext("genres", "News")
  def translated_label(:politics), do: dgettext("genres", "Politics")
  def translated_label(:reality), do: dgettext("genres", "Reality")
  def translated_label(:romance), do: dgettext("genres", "Romance")
  def translated_label(:science_fiction), do: dgettext("genres", "Science Fiction")
  def translated_label(:soap), do: dgettext("genres", "Soap")
  def translated_label(:talk), do: dgettext("genres", "Talk")
  def translated_label(:thriller), do: dgettext("genres", "Thriller")
  def translated_label(:tv_movie), do: dgettext("genres", "TV Movie")
  def translated_label(:war), do: dgettext("genres", "War")
  def translated_label(:western), do: dgettext("genres", "Western")
end
