defmodule WatchClub.Media.ImportPipeline.MatchContent.MatchMovie do
  @moduledoc """
  Resolves a candidate's identity to a `Movie` `Content` row, creating the
  `Content` via `Contents.create_movie/2` when no row exists for the resolved
  TMDB ID.

  Priority:

    1. Explicit TMDB ID from filename / NFO.
    2. IMDB or TVDB ID via TMDB's `/find` endpoint.
    3. TMDB title+year search; top result if `Confidence` passes.
  """

  require Ash.Query

  alias WatchClub.Contents
  alias WatchClub.Contents.Content
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.MatchContent.Confidence

  @type result ::
          {:ok, content_id :: Ash.UUIDv7.t(), movie_id :: Ash.UUIDv7.t(),
           content_action :: :found | :created}
          | {:no_match, String.t()}
          | {:failed, String.t()}

  @spec resolve(Candidate.t(), WatchClub.SystemActor.t()) :: result()
  def resolve(%Candidate{identity: identity}, actor) do
    case resolve_tmdb_id(identity) do
      {:ok, tmdb_id} -> ensure_content(tmdb_id, actor)
      {:no_match, message} -> {:no_match, message}
      {:failed, message} -> {:failed, message}
    end
  end

  # ----------------------------------------------------------------------
  # Step 1 — resolve the candidate to a single TMDB movie id.

  defp resolve_tmdb_id(%Candidate.Identity{external_ids: %{tmdb: tmdb}} = identity)
       when is_binary(tmdb),
       do: parse_id(tmdb, identity)

  defp resolve_tmdb_id(%Candidate.Identity{external_ids: %{imdb: imdb}} = identity)
       when is_binary(imdb),
       do: resolve_via_find(imdb, :imdb_id, identity)

  defp resolve_tmdb_id(%Candidate.Identity{external_ids: %{tvdb: tvdb}} = identity)
       when is_binary(tvdb),
       do: resolve_via_find(tvdb, :tvdb_id, identity)

  defp resolve_tmdb_id(%Candidate.Identity{title: title} = identity)
       when is_binary(title) and title != "",
       do: resolve_via_search(identity)

  defp resolve_tmdb_id(_identity),
    do: {:no_match, "No TMDB/IMDB/TVDB id and no parseable title"}

  defp parse_id(value, identity) do
    case Integer.parse(value) do
      {id, ""} -> {:ok, id}
      _ -> resolve_via_search(identity)
    end
  end

  defp resolve_via_find(external_id, source, identity) do
    case Tmdb.find_by_external_id(external_id, source) do
      {:ok, %{movie_results: [%{id: id} | _]}} ->
        {:ok, id}

      {:ok, _empty} ->
        resolve_via_search(identity)

      {:error, error} ->
        {:failed, "TMDB /find error: #{inspect(error)}"}
    end
  end

  defp resolve_via_search(%Candidate.Identity{title: title} = identity)
       when is_binary(title) and title != "" do
    case Tmdb.search_movie(title, year: identity.year) do
      {:ok, %{results: [top | _]}} ->
        if Confidence.titles_match?(title, top.title) and
             Confidence.years_match?(identity.year, Confidence.date_to_year(top.release_date)) do
          {:ok, top.id}
        else
          {:no_match,
           "Low-confidence TMDB search match for #{inspect(title)} (#{identity.year}): #{inspect(top.title)} (#{inspect(top.release_date)})"}
        end

      {:ok, %{results: []}} ->
        {:no_match, "TMDB search returned no results for #{inspect(title)}"}

      {:error, error} ->
        {:failed, "TMDB search error: #{inspect(error)}"}
    end
  end

  defp resolve_via_search(_identity),
    do: {:no_match, "No title to search TMDB with"}

  # ----------------------------------------------------------------------
  # Step 2 — read existing Content, else create it.

  defp ensure_content(tmdb_id, actor) do
    external_id = Integer.to_string(tmdb_id)

    case existing_content(external_id, actor) do
      {:ok, %Content{id: id, movie: %{id: movie_id}}} ->
        {:ok, id, movie_id, :found}

      {:ok, nil} ->
        case Contents.create_movie(tmdb_id, actor: actor, load: [:movie]) do
          {:ok, %Content{id: id, movie: %{id: movie_id}}} ->
            {:ok, id, movie_id, :created}

          {:error, %Ash.Error.Invalid{} = error} ->
            handle_create_error(error, external_id, actor)
        end

      {:error, error} ->
        {:failed, "Content read error: #{inspect(error)}"}
    end
  end

  defp existing_content(external_id, actor) do
    Content
    |> Ash.Query.filter(
      type == :movie and external_id_source == :tmdb and external_id == ^external_id
    )
    |> Ash.Query.load(:movie)
    |> Ash.read_one(actor: actor)
  end

  # A concurrent import already created the same Content — re-read and continue.
  defp handle_create_error(error, external_id, actor) do
    if duplicate_external_id?(error) do
      case existing_content(external_id, actor) do
        {:ok, %Content{id: id, movie: %{id: movie_id}}} ->
          {:ok, id, movie_id, :found}

        {:ok, nil} ->
          {:failed, "Lost race for #{external_id} but Content was not found on re-read"}

        {:error, e} ->
          {:failed, "Content re-read after race error: #{inspect(e)}"}
      end
    else
      {:failed, "Failed to create movie Content for TMDB id #{external_id}: #{Exception.message(error)}"}
    end
  end

  defp duplicate_external_id?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.InvalidAttribute{field: :external_id} -> true
      _ -> false
    end)
  end
end
