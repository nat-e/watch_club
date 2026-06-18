defmodule WatchClub.Contents.Actions.GetTvShowDetails do
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Integrations.Tmdb

  @impl true
  def run(
        %Ash.ActionInput{arguments: %{tmdb_id: tmdb_id}},
        _opts,
        %Ash.Resource.Actions.Implementation.Context{actor: actor}
      ) do
    actor_locale = actor.settings.locale

    case Tmdb.get_tv_details(tmdb_id, locale: actor_locale) do
      {:ok, response} ->
        {:ok, response}

      {:error, :not_found} ->
        {:error,
         Ash.Error.Query.NotFound.exception(
           primary_key: %{tmdb_id: tmdb_id},
           resource: __MODULE__
         )}
    end
  end
end
