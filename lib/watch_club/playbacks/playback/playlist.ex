defmodule WatchClub.Playbacks.Playback.Playlist do
  @moduledoc """
  Serializes the HLS master and per-track media playlists for a Playback.

  Pure module — callers pass the probed metadata, the quality ladder, the
  segment duration, and the segment count. Nothing here touches disk or
  state.
  """

  alias ExM3U8.MediaPlaylist
  alias ExM3U8.MediaPlaylist.Info, as: MediaPlaylistInfo
  alias ExM3U8.MultivariantPlaylist
  alias ExM3U8.Tags.{Media, Segment, Stream}

  alias WatchClub.Playbacks.Playback.QualityLadder.Quality

  @hls_video_codec "avc1.4d401f"
  @hls_audio_codec "mp4a.40.2"

  # The default audio track is the one every Screen starts with. `query`, such as `?token=…`,
  # follows every URI, because a player resolves them without the playlist's own query.
  @type metadata :: %{
          video: %{frame_rate: float()},
          audio_tracks: [map()],
          default_audio_track_id: String.t() | nil,
          query: String.t()
        }

  @doc """
  Lists no subtitles: every Screen loads the WebVTT files of the Text Tracks itself. AirPlay, which
  only reads them from the playlist, shows none.
  """
  @spec master(metadata(), [Quality.t()]) :: iodata()
  def master(metadata, qualities) do
    %MultivariantPlaylist{
      version: 6,
      independent_segments: true,
      items:
        master_audio_tags(metadata) ++
          Enum.map(qualities, fn quality ->
            %Stream{
              bandwidth: quality.bandwidth,
              average_bandwidth: quality.average_bandwidth,
              codecs: "#{@hls_video_codec},#{@hls_audio_codec}",
              resolution: {quality.width, quality.height},
              frame_rate: metadata.video.frame_rate,
              audio: "audio",
              uri: "video/#{quality.id}/index.m3u8#{metadata.query}"
            }
          end)
    }
    |> ExM3U8.serialize()
  end

  @doc "Segments keep the file's timestamps, so they form a single timeline."
  @spec segments(float(), integer(), float(), String.t()) :: iodata()
  def segments(duration, segment_count, segment_duration, query) do
    target_duration = segment_duration |> Float.ceil() |> trunc()

    %MediaPlaylist{
      info: %MediaPlaylistInfo{
        version: 6,
        target_duration: target_duration,
        media_sequence: 0,
        playlist_type: :vod,
        independent_segments: true,
        end_list?: true
      },
      timeline:
        Enum.map(0..(segment_count - 1), fn index ->
          %Segment{
            duration: segment_duration_at(duration, index, segment_duration),
            uri: "seg_#{pad_segment(index)}.ts#{query}"
          }
        end)
    }
    |> ExM3U8.serialize()
  end

  @spec pad_segment(integer()) :: String.t()
  def pad_segment(index), do: index |> Integer.to_string() |> String.pad_leading(5, "0")

  defp master_audio_tags(metadata) do
    Enum.map(metadata.audio_tracks, fn track ->
      %Media{
        type: :audio,
        group_id: "audio",
        name: escape(track.display_label),
        language: language(track),
        default?: track.id == metadata.default_audio_track_id,
        auto_select?: true,
        channels: "2",
        uri: "audio/#{track.id}/index.m3u8#{metadata.query}"
      }
    end)
  end

  # The same code for a language in every playlist, so the Player can find the
  # previous video's tracks in the next video's
  defp language(track), do: escape(track.language_code || "und")

  defp segment_duration_at(duration, index, segment_duration) do
    remaining = duration - index * segment_duration
    min(segment_duration, max(remaining, 0.1))
  end

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end
end
