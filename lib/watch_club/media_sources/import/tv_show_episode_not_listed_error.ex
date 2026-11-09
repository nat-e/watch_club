defmodule WatchClub.MediaSources.Import.TvShowEpisodeNotListedError do
  @moduledoc "The file's TV Show Episode is still missing after checking the Content's metadata."
  defexception [:tmdb_id, :season_number, :episode_number]

  alias WatchClub.Contents.TvShowEpisode

  @impl true
  def message(error) do
    episode = TvShowEpisode.format_number(error.season_number, error.episode_number)

    "TV Show Episode #{episode} for TMDB TV Show #{error.tmdb_id} is still missing after fetching metadata"
  end
end
