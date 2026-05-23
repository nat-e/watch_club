defmodule WatchClub.Media.ImportPipeline.SaveMedia do
  @moduledoc """
  Final import pipeline stage that saves the Media and related records in the database.
  """

  @behaviour WatchClub.Media.ImportPipeline.Stage

  alias WatchClub.Media
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportRun
  alias WatchClub.SystemActor

  require Logger

  @impl true
  def apply(%Candidate{} = candidate, %ImportRun{snapshot_configuration: configuration}) do
    case save_media(configuration.media_type, candidate) do
      {:ok, _media} ->
        {:ok, candidate}

      {:error, reason} ->
        Logger.error("Error saving media for #{candidate.path}: #{inspect(reason)}")
        {:halt, "Error saving media"}
    end
  end

  defp save_media(media_type, %Candidate{} = candidate)
       when media_type in [:movie, :tv_show_episode] do
    Media.create_or_update_video(
      %{
        path: candidate.path,
        type: media_type,
        video: build_video_input(media_type, candidate)
      },
      actor: SystemActor.actor()
    )
  end

  defp save_media(:ebook, %Candidate{} = candidate) do
    Media.create_or_update_ebook(%{path: candidate.path, ebook: %{}},
      actor: SystemActor.actor()
    )
  end

  defp save_media(:audiobook, %Candidate{} = candidate) do
    Media.create_or_update_audiobook(%{path: candidate.path, audiobook: %{}},
      actor: SystemActor.actor()
    )
  end

  defp build_video_input(
         media_type,
         %Candidate{media_structure: structure, matched_id: matched_id}
       ) do
    foreign_key =
      case media_type do
        :movie -> %{movie_id: matched_id}
        :tv_show_episode -> %{tv_show_episode_id: matched_id}
      end

    Map.merge(foreign_key, %{
      duration_seconds: structure.duration_seconds,
      container: structure.container,
      bit_rate: structure.bit_rate,
      video_tracks: structure.video_tracks,
      audio_tracks: structure.audio_tracks,
      text_tracks: structure.text_tracks
    })
  end
end
