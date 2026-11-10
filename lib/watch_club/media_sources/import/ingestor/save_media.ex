defmodule WatchClub.MediaSources.Import.Ingestor.SaveMedia do
  @moduledoc """
  Final import pipeline stage that saves the Media and related records in the database.
  """

  alias WatchClub.MediaCatalog
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MatchResult
  alias WatchClub.SystemActor

  require Logger

  def apply(%Candidate{media_type: media_type} = candidate)
      when media_type in [:movie, :tv_show_episode, :sports_event] do
    media =
      MediaCatalog.create_or_update_video!(
        %{
          media_source_id: candidate.media_source_id,
          path: candidate.path,
          type: media_type,
          video: build_video_input(media_type, candidate)
        },
        actor: SystemActor.actor(),
        load: :video
      )

    if candidate.regenerate_thumbnails_and_markers? do
      MediaCatalog.regenerate_thumbnails_and_markers!(media.video, actor: SystemActor.actor())
    end

    Logger.info("Successfully imported #{candidate.path}", event: :save_media_success)
    media
  end

  def apply(%Candidate{media_type: :audiobook} = candidate) do
    media =
      MediaCatalog.create_or_update_audiobook!(
        %{media_source_id: candidate.media_source_id, path: candidate.path, audiobook: %{}},
        actor: SystemActor.actor()
      )

    Logger.info("Successfully imported #{candidate.path}", event: :save_media_success)
    media
  end

  def apply(%Candidate{media_type: :ebook} = candidate) do
    media =
      MediaCatalog.create_or_update_ebook!(
        %{media_source_id: candidate.media_source_id, path: candidate.path, ebook: %{}},
        actor: SystemActor.actor()
      )

    Logger.info("Successfully imported #{candidate.path}", event: :save_media_success)
    media
  end

  defp build_video_input(
         media_type,
         %Candidate{
           media_structure: structure,
           match_result: %MatchResult{matched_id: matched_id}
         }
       ) do
    foreign_key =
      case media_type do
        :movie -> %{movie_id: matched_id}
        :tv_show_episode -> %{tv_show_episode_id: matched_id}
        :sports_event -> %{sports_event_id: matched_id}
      end

    Map.merge(foreign_key, %{
      file_fingerprint: structure.file_fingerprint,
      duration_seconds: structure.duration_seconds,
      container: structure.container,
      bit_rate: structure.bit_rate,
      video_tracks: structure.video_tracks,
      audio_tracks: structure.audio_tracks,
      text_tracks: structure.text_tracks
    })
  end
end
