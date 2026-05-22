defmodule WatchClub.Media.ImportPipeline.MatchContent.MatchTvShowEpisode do
  @moduledoc """
  Resolves a candidate's identity to a `TvShowEpisode`, creating the parent
  `TvShow` `Content` via `Contents.create_tv_show/2` if missing, or refreshing
  it via `Contents.refresh_tv_show/2` when the expected episode is not yet
  present on an existing show. Episodes are never created in isolation — they
  always come from the whole-show payload.
  """

  require Ash.Query

  alias WatchClub.Contents
  alias WatchClub.Contents.{Content, TvShowEpisode}
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.MatchContent.Confidence

  @type result ::
          {:ok, content_id :: Ash.UUIDv7.t(), episode_id :: Ash.UUIDv7.t(),
           content_action :: :found | :created | :refreshed}
          | {:no_match, String.t()}
          | {:failed, String.t()}

  @spec resolve(Candidate.t(), WatchClub.SystemActor.t()) :: result()
  def resolve(%Candidate{identity: identity}, actor) do
    with {:ok, season, episode} <- require_season_episode(identity),
         {:ok, tmdb_id} <- resolve_show_tmdb_id(identity),
         {:ok, content, action} <- ensure_show(tmdb_id, actor),
         {:ok, episode_id, action} <- ensure_episode(content, season, episode, tmdb_id, actor, action) do
      {:ok, content.id, episode_id, action}
    end
  end

  defp require_season_episode(%Candidate.Identity{
         season_number: s,
         episode_number: e
       })
       when is_integer(s) and is_integer(e),
       do: {:ok, s, e}

  defp require_season_episode(_),
    do: {:no_match, "Candidate has no parseable season+episode"}

  # ----------------------------------------------------------------------
  # Resolve to a TMDB show id.

  defp resolve_show_tmdb_id(%Candidate.Identity{show_external_ids: %{tmdb: tmdb}} = identity)
       when is_binary(tmdb),
       do: parse_id(tmdb, identity)

  defp resolve_show_tmdb_id(%Candidate.Identity{show_external_ids: %{imdb: imdb}} = identity)
       when is_binary(imdb),
       do: resolve_via_find(imdb, :imdb_id, identity)

  defp resolve_show_tmdb_id(%Candidate.Identity{show_external_ids: %{tvdb: tvdb}} = identity)
       when is_binary(tvdb),
       do: resolve_via_find(tvdb, :tvdb_id, identity)

  defp resolve_show_tmdb_id(%Candidate.Identity{show_title: title} = identity)
       when is_binary(title) and title != "",
       do: resolve_via_search(identity)

  defp resolve_show_tmdb_id(_),
    do: {:no_match, "No TMDB/IMDB/TVDB show id and no parseable show title"}

  defp parse_id(value, identity) do
    case Integer.parse(value) do
      {id, ""} -> {:ok, id}
      _ -> resolve_via_search(identity)
    end
  end

  defp resolve_via_find(external_id, source, identity) do
    case Tmdb.find_by_external_id(external_id, source) do
      {:ok, %{tv_results: [%{id: id} | _]}} ->
        {:ok, id}

      {:ok, _empty} ->
        resolve_via_search(identity)

      {:error, error} ->
        {:failed, "TMDB /find error: #{inspect(error)}"}
    end
  end

  defp resolve_via_search(%Candidate.Identity{show_title: title} = identity)
       when is_binary(title) and title != "" do
    case Tmdb.search_tv(title, year: identity.show_year) do
      {:ok, %{results: [top | _]}} ->
        if Confidence.titles_match?(title, top.name) and
             Confidence.years_match?(
               identity.show_year,
               Confidence.date_to_year(top.first_air_date)
             ) do
          {:ok, top.id}
        else
          {:no_match,
           "Low-confidence TMDB search match for show #{inspect(title)} (#{identity.show_year}): #{inspect(top.name)} (#{inspect(top.first_air_date)})"}
        end

      {:ok, %{results: []}} ->
        {:no_match, "TMDB search returned no TV results for #{inspect(title)}"}

      {:error, error} ->
        {:failed, "TMDB search error: #{inspect(error)}"}
    end
  end

  defp resolve_via_search(_), do: {:no_match, "No title to search TMDB with"}

  # ----------------------------------------------------------------------
  # Ensure the TvShow Content exists.

  defp ensure_show(tmdb_id, actor) do
    external_id = Integer.to_string(tmdb_id)

    case existing_show(external_id, actor) do
      {:ok, %Content{} = content} ->
        {:ok, content, :found}

      {:ok, nil} ->
        case Contents.create_tv_show(tmdb_id, actor: actor) do
          {:ok, %Content{} = content} ->
            {:ok, content, :created}

          {:error, %Ash.Error.Invalid{} = error} ->
            handle_create_error(error, external_id, actor)
        end

      {:error, error} ->
        {:failed, "Content read error: #{inspect(error)}"}
    end
  end

  defp existing_show(external_id, actor) do
    Content
    |> Ash.Query.filter(
      type == :tv_show and external_id_source == :tmdb and external_id == ^external_id
    )
    |> Ash.read_one(actor: actor)
  end

  defp handle_create_error(error, external_id, actor) do
    if duplicate_external_id?(error) do
      case existing_show(external_id, actor) do
        {:ok, %Content{} = content} -> {:ok, content, :found}
        {:ok, nil} -> {:failed, "Lost race for TV show #{external_id} but Content was not found on re-read"}
        {:error, e} -> {:failed, "Content re-read after race error: #{inspect(e)}"}
      end
    else
      {:failed, "Failed to create TV show Content for TMDB id #{external_id}: #{Exception.message(error)}"}
    end
  end

  defp duplicate_external_id?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.InvalidAttribute{field: :external_id} -> true
      _ -> false
    end)
  end

  # ----------------------------------------------------------------------
  # Ensure the target episode exists. Refresh the show as a whole if missing.

  defp ensure_episode(%Content{} = content, season, episode, tmdb_id, actor, content_action) do
    case episode_for(content.id, season, episode, actor) do
      {:ok, %TvShowEpisode{id: id}} ->
        {:ok, id, content_action}

      {:ok, nil} when content_action == :created ->
        # Just-created show with all known episodes, but the candidate's S/E is
        # not in TMDB — no match.
        {:no_match,
         "Episode S#{season}E#{episode} not found on freshly created TV show TMDB id #{tmdb_id}"}

      {:ok, nil} ->
        refresh_and_lookup(content, season, episode, tmdb_id, actor)

      {:error, error} ->
        {:failed, "Episode read error: #{inspect(error)}"}
    end
  end

  defp refresh_and_lookup(%Content{} = content, season, episode, tmdb_id, actor) do
    case Contents.refresh_tv_show(content, tmdb_id, actor: actor) do
      {:ok, _content} ->
        case episode_for(content.id, season, episode, actor) do
          {:ok, %TvShowEpisode{id: id}} ->
            {:ok, id, :refreshed}

          {:ok, nil} ->
            {:no_match,
             "Episode S#{season}E#{episode} still missing after refresh of TV show TMDB id #{tmdb_id}"}

          {:error, error} ->
            {:failed, "Episode re-read error: #{inspect(error)}"}
        end

      {:error, error} ->
        {:failed, "Failed to refresh TV show TMDB id #{tmdb_id}: #{Exception.message(error)}"}
    end
  end

  defp episode_for(tv_show_id, season, episode, actor) do
    TvShowEpisode
    |> Ash.Query.filter(
      tv_show_id == ^tv_show_id and season_number == ^season and episode_number == ^episode
    )
    |> Ash.read_one(actor: actor)
  end
end
