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
  alias ExM3U8.Tags.{Discontinuity, Media, Segment, Stream}

  alias WatchClub.Playbacks.Playback.QualityLadder.Quality

  @hls_video_codec "avc1.4d401f"
  @hls_audio_codec "mp4a.40.2"

  @type metadata :: %{
          video: %{frame_rate: float()},
          audio_tracks: [map()],
          subtitle_tracks: [map()]
        }

  @spec master(metadata(), [Quality.t()]) :: iodata()
  def master(metadata, qualities) do
    subtitle_group = if metadata.subtitle_tracks == [], do: nil, else: "subs"

    %MultivariantPlaylist{
      version: 6,
      independent_segments: true,
      items:
        master_audio_tags(metadata.audio_tracks) ++
          master_subtitle_tags(metadata.subtitle_tracks) ++
          Enum.map(qualities, fn quality ->
            %Stream{
              bandwidth: quality.bandwidth,
              average_bandwidth: quality.average_bandwidth,
              codecs: "#{@hls_video_codec},#{@hls_audio_codec}",
              resolution: {quality.width, quality.height},
              frame_rate: metadata.video.frame_rate,
              audio: "audio",
              subtitles: subtitle_group,
              uri: "video/#{quality.id}/index.m3u8"
            }
          end)
    }
    |> ExM3U8.serialize()
  end

  @spec segments(float(), integer(), float()) :: iodata()
  def segments(duration, segment_count, segment_duration) do
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
        Enum.flat_map(0..(segment_count - 1), fn index ->
          segment = %Segment{
            duration: segment_duration_at(duration, index, segment_duration),
            uri: "seg_#{pad_segment(index)}.ts"
          }

          if index == 0, do: [segment], else: [%Discontinuity{}, segment]
        end)
    }
    |> ExM3U8.serialize()
  end

  @spec subtitle(map(), float()) :: iodata()
  def subtitle(track, duration) do
    target_duration = duration |> Float.ceil() |> trunc()

    %MediaPlaylist{
      info: %MediaPlaylistInfo{
        version: 6,
        target_duration: target_duration,
        media_sequence: 0,
        playlist_type: :vod,
        end_list?: true
      },
      timeline: [%Segment{duration: duration, uri: "#{track.id}.vtt"}]
    }
    |> ExM3U8.serialize()
  end

  @spec pad_segment(integer()) :: String.t()
  def pad_segment(index), do: index |> Integer.to_string() |> String.pad_leading(5, "0")

  defp master_audio_tags(audio_tracks) do
    Enum.map(audio_tracks, fn track ->
      %Media{
        type: :audio,
        group_id: "audio",
        name: escape(track.display_label),
        language: escape(track.language || "und"),
        default?: track.default?,
        auto_select?: true,
        channels: "2",
        uri: "audio/#{track.id}/index.m3u8"
      }
    end)
  end

  defp master_subtitle_tags(subtitle_tracks) do
    Enum.map(subtitle_tracks, fn track ->
      %Media{
        type: :subtitles,
        group_id: "subs",
        name: escape(track.display_label),
        language: escape(track.language || "und"),
        default?: track.default?,
        auto_select?: true,
        uri: "subtitles/#{track.id}/index.m3u8"
      }
    end)
  end

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
