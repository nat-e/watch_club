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

  alias WatchClub.Languages
  alias WatchClub.Playbacks.Playback.QualityLadder.Quality

  defmodule SubtitlesMedia do
    @moduledoc """
    A subtitles media tag, with `FORCED=YES` for a Forced Text Track and the accessibility
    characteristics of an SDH Text Track, which ExM3U8's media tag can't serialize.
    """

    defstruct [:media, :forced?, :sdh?]

    defimpl ExM3U8.Serializer do
      def serialize(%{media: media, forced?: forced?, sdh?: sdh?}) do
        [
          ExM3U8.Serializer.serialize(media),
          if(forced?, do: ",FORCED=YES", else: []),
          if(sdh?,
            do:
              ~s(,CHARACTERISTICS="public.accessibility.transcribes-spoken-dialog,public.accessibility.describes-music-and-sound"),
            else: []
          )
        ]
      end
    end
  end

  @hls_video_codec "avc1.4d401f"
  @hls_audio_codec "mp4a.40.2"

  # The default tracks are the ones every Screen starts with. `query`, such as `?token=…`, follows
  # every URI, because a player resolves them without the playlist's own query.
  @type metadata :: %{
          video: %{frame_rate: float()},
          audio_tracks: [map()],
          subtitle_tracks: [map()],
          subtitle_names: %{String.t() => String.t()},
          default_audio_track_id: String.t() | nil,
          default_subtitle_track_id: String.t() | nil,
          query: String.t()
        }

  @spec master(metadata(), [Quality.t()]) :: iodata()
  def master(metadata, qualities) do
    subtitle_group = if metadata.subtitle_tracks == [], do: nil, else: "subs"

    %MultivariantPlaylist{
      version: 6,
      independent_segments: true,
      items:
        master_audio_tags(metadata) ++
          master_subtitle_tags(metadata) ++
          Enum.map(qualities, fn quality ->
            %Stream{
              bandwidth: quality.bandwidth,
              average_bandwidth: quality.average_bandwidth,
              codecs: "#{@hls_video_codec},#{@hls_audio_codec}",
              resolution: {quality.width, quality.height},
              frame_rate: metadata.video.frame_rate,
              audio: "audio",
              subtitles: subtitle_group,
              uri: "video/#{quality.id}/index.m3u8#{metadata.query}"
            }
          end)
    }
    |> ExM3U8.serialize()
  end

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
        Enum.flat_map(0..(segment_count - 1), fn index ->
          segment = %Segment{
            duration: segment_duration_at(duration, index, segment_duration),
            uri: "seg_#{pad_segment(index)}.ts#{query}"
          }

          if index == 0, do: [segment], else: [%Discontinuity{}, segment]
        end)
    }
    |> ExM3U8.serialize()
  end

  @spec subtitle(map(), float(), String.t()) :: iodata()
  def subtitle(track, duration, query) do
    target_duration = duration |> Float.ceil() |> trunc()

    %MediaPlaylist{
      info: %MediaPlaylistInfo{
        version: 6,
        target_duration: target_duration,
        media_sequence: 0,
        playlist_type: :vod,
        end_list?: true
      },
      timeline: [%Segment{duration: duration, uri: "#{track.id}.vtt#{query}"}]
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

  defp master_subtitle_tags(metadata) do
    Enum.map(metadata.subtitle_tracks, fn track ->
      %SubtitlesMedia{
        media: %Media{
          type: :subtitles,
          group_id: "subs",
          name: escape(metadata.subtitle_names[track.id]),
          language: escape(Languages.to_tag(track.language) || "und"),
          default?: track.id == metadata.default_subtitle_track_id,
          auto_select?: true,
          uri: "subtitles/#{track.id}/index.m3u8#{metadata.query}"
        },
        forced?: track.forced?,
        sdh?: track.sdh?
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
