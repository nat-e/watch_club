defmodule WatchClub.MediaSources.Import.Ingestor.SaveMedia do
  @moduledoc """
  Final import pipeline stage that saves the Media and related records in the database.
  """

  alias WatchClub.MediaCatalog
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MatchResult
  alias WatchClub.SystemActor

  def apply!(%Candidate{media_type: media_type} = candidate)
      when media_type in [:movie, :tv_show_episode, :sports_event] do
    MediaCatalog.create_or_update_video!(
      %{
        media_source_id: candidate.media_source_id,
        path: candidate.path,
        type: media_type,
        file_stamp: candidate.file_stamp,
        video: build_video_input(candidate)
      },
      actor: SystemActor.actor(),
      load: :video
    )
  end

  def apply!(%Candidate{media_type: :audiobook} = candidate) do
    MediaCatalog.create_or_update_audiobook!(
      %{
        media_source_id: candidate.media_source_id,
        path: candidate.path,
        file_stamp: candidate.file_stamp,
        audiobook: %{}
      },
      actor: SystemActor.actor()
    )
  end

  def apply!(%Candidate{media_type: :ebook} = candidate) do
    MediaCatalog.create_or_update_ebook!(
      %{
        media_source_id: candidate.media_source_id,
        path: candidate.path,
        file_stamp: candidate.file_stamp,
        ebook: %{}
      },
      actor: SystemActor.actor()
    )
  end

  defp build_video_input(%Candidate{
         media_structure: structure,
         match_result: %MatchResult{parts: parts}
       }) do
    %{
      parts: parts,
      file_fingerprint: structure.file_fingerprint,
      duration_seconds: structure.duration_seconds,
      container: structure.container,
      bit_rate: structure.bit_rate,
      keyframe_seconds: structure.keyframe_seconds,
      keyframe_interval_bytes: structure.keyframe_interval_bytes,
      video_tracks: structure.video_tracks,
      # As maps, so the Video matches them with the tracks it already has: Ash would match a
      # struct by its `video_id`, which these don't have
      audio_tracks: Enum.map(structure.audio_tracks, &Map.from_struct/1),
      text_tracks: Enum.map(structure.text_tracks, &Map.from_struct/1)
    }
  end
end
