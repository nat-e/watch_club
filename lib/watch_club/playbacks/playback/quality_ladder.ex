defmodule WatchClub.Playbacks.Playback.QualityLadder do
  @moduledoc """
  Builds the list of HLS variants offered for a Video, from its Default Video Track.

  The "original" variant copies the file's video when it's 8-bit H.264, which browsers and TVs
  decode. Otherwise it's encoded at the source's size, at a bitrate capped from the source's.
  The ladder adds 720p / 480p / 360p rungs as long as the source is taller. Each rung carries
  its width, height, video bitrate, H.264 level, codecs, and the bandwidth values exposed in the
  master playlist. The codecs tell a Screen whether it can decode the rung.
  """

  alias WatchClub.MediaCatalog.{Video, VideoTrack}

  defmodule Quality do
    @moduledoc false
    @enforce_keys [
      :id,
      :label,
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
            label: String.t(),
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
    %{id: "720p", label: "720p", height: 720, video_bitrate: 2_800_000},
    %{id: "480p", label: "480p", height: 480, video_bitrate: 1_400_000},
    %{id: "360p", label: "360p", height: 360, video_bitrate: 800_000}
  ]

  @audio_bandwidth_overhead 192_000
  @audio_average_bandwidth_overhead 160_000
  @default_source_bit_rate 2_500_000
  @min_original_bitrate 3_500_000
  @max_original_bitrate 6_500_000

  @doc "Needs the Video's `default_video_track` loaded."
  @spec build(Video.t()) :: [Quality.t()]
  def build(%Video{default_video_track: %VideoTrack{} = track} = video) do
    # A Matroska file may not give its video's bit rate
    source_bit_rate = track.bit_rate || video.bit_rate || @default_source_bit_rate

    [
      original(track, source_bit_rate)
      | for(rung <- @encoded_rungs, rung.height < track.height, do: encoded(rung, track))
    ]
  end

  defp original(track, source_bit_rate) do
    label = "Original (#{track.height}p)"

    case track do
      # A copy's peak bit rate isn't known: twice its average
      %VideoTrack{codec: "h264", profile: profile, level: level}
      when is_map_key(@h264_profiles, profile) and is_integer(level) ->
        %Quality{
          id: "original",
          label: label,
          width: track.width,
          height: track.height,
          copy?: true,
          video_bitrate: source_bit_rate,
          level: level,
          codecs: codecs(@h264_profiles[profile], level),
          bandwidth: source_bit_rate * 2 + @audio_bandwidth_overhead,
          average_bandwidth: source_bit_rate + @audio_average_bandwidth_overhead
        }

      _other ->
        video_bitrate =
          (source_bit_rate * 2)
          |> max(@min_original_bitrate)
          |> min(@max_original_bitrate)

        encoded(
          %{id: "original", label: label, height: track.height, video_bitrate: video_bitrate},
          track
        )
    end
  end

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
      label: rung.label,
      width: width,
      height: rung.height,
      copy?: false,
      video_bitrate: rung.video_bitrate,
      level: level,
      # x264 marks its Constrained Baseline with the constraint flags 0 and 1
      codecs: codecs("42c0", level),
      bandwidth: rung.video_bitrate + @audio_bandwidth_overhead,
      average_bandwidth: rung.video_bitrate + @audio_average_bandwidth_overhead
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
