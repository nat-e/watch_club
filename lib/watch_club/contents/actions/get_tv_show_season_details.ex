defmodule WatchClub.Contents.Actions.GetTvShowSeasonDetails do
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Integrations.Tmdb

  @impl true
  def run(
        %Ash.ActionInput{arguments: %{tmdb_id: tmdb_id, season_number: season_number}},
        _opts,
        %Ash.Resource.Actions.Implementation.Context{actor: actor}
      ) do
    Tmdb.get_tv_season_details(tmdb_id, season_number, locale: actor.settings.locale)
  end
end
