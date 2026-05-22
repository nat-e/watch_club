defmodule WatchClub.Media.ImportPipeline.MatchContent do
  @moduledoc """
  Final import pipeline stage. Takes a candidate that has already had its
  identity and media structure extracted, and:

    1. Resolves the candidate's identity to a `Content` row (`Movie` or
       `TvShowEpisode`'s parent `TvShow`), creating the `Content` if missing.
    2. For TV shows, ensures the target `TvShowEpisode` exists — refreshing
       the whole TV show from TMDB if the episode is not yet known.
    3. Persists a `Media` row (or replaces the concrete `Video` on an existing
       `Media` when `Refresh Metadata` is on), wired to the resolved
       attachment, with track rows built from `candidate.media_structure`.
    4. Sets `Media.last_successful_media_import_id` to the current run.

  Outcomes:

    * `:created` — fresh `Media` written for this candidate.
    * `:updated` — existing `Media` rebuilt against new probe data.
    * `:no_match` — identity could not be confidently matched.
    * `:failed` — TMDB or persistence error.

  Books are not yet supported and always halt with `:no_match`.
  """

  @behaviour WatchClub.Media.ImportPipeline.Stage

  alias WatchClub.Media
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.MatchInfo
  alias WatchClub.Media.ImportPipeline.MatchContent.{MatchMovie, MatchTvShowEpisode}
  alias WatchClub.Media.ImportRun
  alias WatchClub.SystemActor

  @impl true
  def apply(%Candidate{} = candidate, %ImportRun{snapshot_configuration: configuration} = run) do
    actor = SystemActor.actor()

    case configuration.content_type do
      :movie -> match_movie(candidate, run, actor)
      :tv_show -> match_tv_show(candidate, run, actor)
      :book -> {:halt, candidate, :no_match, "Book matching not yet implemented"}
    end
  end

  defp match_movie(candidate, run, actor) do
    case MatchMovie.resolve(candidate, actor) do
      {:ok, content_id, movie_id, content_action} ->
        persist(candidate, run, actor, content_id, {:movie, movie_id}, content_action)

      {:no_match, message} ->
        {:halt, candidate, :no_match, message}

      {:failed, message} ->
        {:halt, candidate, :failed, message}
    end
  end

  defp match_tv_show(candidate, run, actor) do
    case MatchTvShowEpisode.resolve(candidate, actor) do
      {:ok, content_id, episode_id, content_action} ->
        persist(candidate, run, actor, content_id, {:episode, episode_id}, content_action)

      {:no_match, message} ->
        {:halt, candidate, :no_match, message}

      {:failed, message} ->
        {:halt, candidate, :failed, message}
    end
  end

  # ----------------------------------------------------------------------
  # Persistence

  defp persist(candidate, run, actor, content_id, attachment, content_action) do
    case write_media(candidate, attachment, actor) do
      {:ok, media, :created} ->
        finalize(candidate, run, actor, media, content_id, attachment, content_action, :created)

      {:ok, media, :updated} ->
        finalize(candidate, run, actor, media, content_id, attachment, content_action, :updated)

      {:error, error} ->
        {:halt, candidate, :failed, "Failed to persist Media: #{Exception.message(error)}"}
    end
  end

  defp write_media(%Candidate{existing_media: %{id: id}} = candidate, attachment, actor) do
    video_input = build_video_input(candidate, attachment)

    with {:ok, media} <- Ash.get(WatchClub.Media.Media, id, actor: actor),
         {:ok, media} <- Media.update_video(media, %{video: video_input}, actor: actor) do
      {:ok, media, :updated}
    end
  end

  defp write_media(%Candidate{} = candidate, attachment, actor) do
    video_input = build_video_input(candidate, attachment)

    case Media.create_video(%{path: candidate.path, video: video_input}, actor: actor) do
      {:ok, media} -> {:ok, media, :created}
      {:error, error} -> {:error, error}
    end
  end

  defp build_video_input(%Candidate{media_structure: structure}, attachment) do
    attachment_attrs = attachment_attrs(attachment)

    Map.merge(attachment_attrs, %{
      duration_seconds: structure.duration_seconds,
      container: structure.container,
      bit_rate: structure.bit_rate,
      video_tracks: Enum.map(structure.video_tracks, &track_to_map/1),
      audio_tracks: Enum.map(structure.audio_tracks, &track_to_map/1),
      text_tracks: Enum.map(structure.text_tracks, &track_to_map/1)
    })
  end

  # Drop fields not accepted by the track resources (e.g. `hearing_impaired?`).
  @track_attrs ~w(stream_index sidecar_path codec language title channels width height
                  frame_rate bit_rate default? forced?)a
  defp track_to_map(track) do
    track
    |> Map.from_struct()
    |> Map.take(@track_attrs)
  end

  defp attachment_attrs({:movie, movie_id}), do: %{movie_id: movie_id}
  defp attachment_attrs({:episode, episode_id}), do: %{tv_show_episode_id: episode_id}

  defp finalize(candidate, run, actor, media, content_id, attachment, content_action, outcome) do
    case Media.assign_last_successful_import(
           media,
           %{last_successful_media_import_id: run.id},
           actor: actor
         ) do
      {:ok, _media} ->
        candidate = %{
          candidate
          | match: %MatchInfo{
              media_id: media.id,
              content_id: content_id,
              attachment: attachment,
              content_action: content_action
            }
        }

        {:ok, set_outcome(candidate, outcome)}

      {:error, error} ->
        {:halt, candidate, :failed,
         "Failed to assign last successful Media Import: #{Exception.message(error)}"}
    end
  end

  defp set_outcome(candidate, :created), do: Candidate.set_created_outcome(candidate)
  defp set_outcome(candidate, :updated), do: Candidate.set_updated_outcome(candidate)
end
