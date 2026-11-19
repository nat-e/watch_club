defmodule WatchClub.Playbacks.Playback.QualityLadder do
  @moduledoc """
  Builds the list of HLS variants offered for a Video, its Qualities, from its Default Video
  Track.

  The Original copies the file's video when it's 8-bit H.264, which browsers and TVs decode.
  Otherwise it's encoded at the source's size, at a bitrate capped from the source's. The ladder
  adds 720p / 480p / 360p rungs as long as the source is taller. Each rung carries its width,
  height, video bitrate, H.264 level, codecs, and the bandwidth values exposed in the master
  playlist. The codecs tell a Screen whether it can decode the rung.

  A Quality's id is its name, such as 1080p, which the Player's menu shows, and which a Playback
  Session's Quality matches from one Video to the next.

  A copy's bandwidth values are the peak and average bit rates of its segments, as RFC 8216
  defines them, measured from the bytes of the file's video in each segment. Every rung's
  include the MPEG-TS overhead and the audio.
  """

  alias WatchClub.MediaCatalog.{Video, VideoTrack}
  alias WatchClub.Playbacks.Playback.Playlist

  defmodule Quality do
    @moduledoc false
    @enforce_keys [
      :id,
      :width,
      :height,
      :copy?,
      :video_bitrate,
      :level,
      :codecs,
      :bandwidth,
      :average_bandwidth
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            id: String.t(),
            width: integer(),
            height: integer(),
            copy?: boolean(),
            video_bitrate: integer(),
            level: integer(),
            codecs: String.t(),
            bandwidth: integer(),
            average_bandwidth: integer()
          }
  end

  # The H.264 profiles that browsers and TVs decode, with the RFC 6381 profile and constraint
  # bytes of each
  @h264_profiles %{
    "Constrained Baseline" => "42e0",
    "Baseline" => "4200",
    "Main" => "4d40",
    "High" => "6400"
  }

  # The H.264 levels of encoded rungs, as {level, max macroblocks per frame, max macroblocks per
  # second}. They start at 3.1: the Original's VBV buffer, twice its bitrate in `WatchClub.Ffmpeg`,
  # reaches 13 Mbit, over 3.0's limit of 10 Mbit but under 3.1's 14 Mbit, so
  # `@max_original_bitrate` must stay under 7 Mbps. Levels that only raise the bitrate, such as
  # 4.1, are left out.
  @h264_levels [
    {31, 3_600, 108_000},
    {32, 5_120, 216_000},
    {40, 8_192, 245_760},
    {42, 8_704, 522_240},
    {50, 22_080, 589_824},
    {51, 36_864, 983_040},
    {52, 36_864, 2_073_600},
    {60, 139_264, 4_177_920},
    {61, 139_264, 8_355_840},
    {62, 139_264, 16_711_680}
  ]

  @encoded_rungs [
    %{id: "720p", height: 720, video_bitrate: 2_800_000},
    %{id: "480p", height: 480, video_bitrate: 1_400_000},
    %{id: "360p", height: 360, video_bitrate: 800_000}
  ]

  # The heights Video.js names a rendition wider than 16:9 by, from its width
  @standard_heights [4320, 2160, 1440, 1080, 720, 480, 360, 240]

  # The peak and average bit rates of the audio segments, 160 kbit/s AAC in MPEG-TS, as measured
  @audio_peak_bit_rate 250_000
  @audio_average_bit_rate 245_000
  @default_source_bit_rate 2_500_000
  @min_original_bitrate 3_500_000
  @max_original_bitrate 6_500_000

  @doc """
  Needs the Video's `default_video_track` loaded, and its segments, in order, with their
  `start_time`, `end_time`, `duration` and `video_bytes`.
  """
  @spec build(Video.t(), [map()]) :: [Quality.t()]
  def build(%Video{default_video_track: %VideoTrack{} = track} = video, segments),
    do: [original(video, segments) | Enum.map(encoded_rungs(track), &encoded(&1, track))]

  @doc "The ids of the Video's Qualities, best first. Needs its `default_video_track` loaded."
  @spec ids(Video.t()) :: [String.t()]
  def ids(%Video{default_video_track: %VideoTrack{} = track}),
    do: [original_id(track) | Enum.map(encoded_rungs(track), & &1.id)]

  defp encoded_rungs(track), do: Enum.filter(@encoded_rungs, &(&1.height < track.height))

  # Named as Video.js names it, by the standard height of its width when it's wider than 16:9: a
  # 1920×800 Original is 1080p. Otherwise by its height, which is over every encoded rung's.
  defp original_id(%VideoTrack{width: width, height: height}) do
    widescreen_height = round(width * 9 / 16)

    if width * 9 > height * 16 and widescreen_height in @standard_heights,
      do: "#{widescreen_height}p",
      else: "#{height}p"
  end

  defp original(%Video{default_video_track: track} = video, segments) do
    case track do
      %VideoTrack{codec: "h264", profile: profile, level: level}
      when is_map_key(@h264_profiles, profile) and is_integer(level) ->
        {peak_bit_rate, average_bit_rate} = copy_bit_rates(video, segments)

        %Quality{
          id: original_id(track),
          width: track.width,
          height: track.height,
          copy?: true,
          video_bitrate: average_bit_rate,
          level: level,
          codecs: codecs(@h264_profiles[profile], level),
          bandwidth: in_mpeg_ts(peak_bit_rate, track) + @audio_peak_bit_rate,
          average_bandwidth: in_mpeg_ts(average_bit_rate, track) + @audio_average_bit_rate
        }

      _other ->
        # A Matroska file may not give its video's bit rate
        source_bit_rate = track.bit_rate || video.bit_rate || @default_source_bit_rate

        video_bitrate =
          (source_bit_rate * 2)
          |> max(@min_original_bitrate)
          |> min(@max_original_bitrate)

        encoded(
          %{id: original_id(track), height: track.height, video_bitrate: video_bitrate},
          track
        )
    end
  end

  # The peak and average bit rates of the copy's video
  defp copy_bit_rates(video, segments) do
    target_duration = segments |> Enum.map(& &1.duration) |> Playlist.target_duration()
    video_bytes = segments |> Enum.map(& &1.video_bytes) |> Enum.sum()
    average_bit_rate = round(video_bytes * 8 / video.duration_seconds)

    # RFC 8216's peak: the highest bit rate over any run of consecutive segments that lasts from
    # half to one and a half target durations
    peak_bit_rate =
      segments
      |> Stream.unfold(fn
        [] -> nil
        [_first | rest] = run -> {run, rest}
      end)
      |> Stream.flat_map(fn [first | _] = run ->
        run
        |> Stream.scan({0, 0.0}, fn segment, {bytes, _duration} ->
          {bytes + segment.video_bytes, segment.end_time - first.start_time}
        end)
        |> Stream.take_while(fn {_bytes, duration} -> duration <= 1.5 * target_duration end)
        |> Stream.filter(fn {_bytes, duration} -> duration >= 0.5 * target_duration end)
        |> Stream.map(fn {bytes, duration} -> round(bytes * 8 / duration) end)
      end)
      # A Video shorter than half a second has no such run
      |> Enum.max(fn -> average_bit_rate end)

    {peak_bit_rate, average_bit_rate}
  end

  # MPEG-TS carries 184 bytes in each 188-byte packet, and adds about 23 kbit/s of tables and
  # 1.1 kbit/s for each frame per second, as measured on segments at 24 and 60 fps. An unknown
  # frame rate counts as 60.
  defp in_mpeg_ts(bit_rate, track),
    do: round(bit_rate * 188 / 184 + 23_000 + (track.frame_rate || 60) * 1_100)

  defp encoded(rung, track) do
    width = scaled_width(rung.height, track.width, track.height)
    macroblocks = div(width + 15, 16) * div(rung.height + 15, 16)
    # The average frame rate: a variable one can peak above it. An unknown one counts as 60.
    macroblocks_per_second = macroblocks * (track.frame_rate || 60)

    {level, _max_macroblocks, _max_macroblocks_per_second} =
      Enum.find(@h264_levels, List.last(@h264_levels), fn {_level, max, max_per_second} ->
        macroblocks <= max and macroblocks_per_second <= max_per_second
      end)

    %Quality{
      id: rung.id,
      width: width,
      height: rung.height,
      copy?: false,
      video_bitrate: rung.video_bitrate,
      level: level,
      # x264 marks its Constrained Baseline with the constraint flags 0 and 1
      codecs: codecs("42c0", level),
      bandwidth: in_mpeg_ts(rung.video_bitrate, track) + @audio_peak_bit_rate,
      average_bandwidth: in_mpeg_ts(rung.video_bitrate, track) + @audio_average_bit_rate
    }
  end

  # RFC 6381 codecs, such as avc1.640029 for High 4.1
  defp codecs(profile_and_constraints, level) do
    level = level |> Integer.to_string(16) |> String.pad_leading(2, "0") |> String.downcase()
    "avc1.#{profile_and_constraints}#{level}"
  end

  defp scaled_width(height, source_width, source_height) do
    width = round(source_width * height / source_height)

    if rem(width, 2) == 0, do: width, else: width + 1
  end
end
