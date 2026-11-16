defmodule WatchClub.Playbacks.Playback.QualityLadder do
  @moduledoc """
  Builds the list of HLS variants offered for a Video, from its Default Video Track.

  The "original" variant copies the file's video when it's 8-bit H.264, which browsers and TVs
  decode. Otherwise it's encoded at the source's size, at a bitrate capped from the source's.
  The ladder adds 720p / 480p / 360p rungs as long as the source is taller. Each rung carries
  its width, height, video bitrate, codecs, and the bandwidth values exposed in the master
  playlist.
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
            codecs: String.t(),
            bandwidth: integer(),
            average_bandwidth: integer()
          }
  end

  # The profiles of 8-bit H.264, with the RFC 6381 profile and constraint bytes of each
  @copied_h264_profiles %{
    "Constrained Baseline" => "42e0",
    "Baseline" => "4200",
    "Main" => "4d40",
    "High" => "6400"
  }

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

    case copied_codecs(track) do
      # A copy's peak bit rate isn't known: twice its average
      {:ok, codecs} ->
        %Quality{
          id: "original",
          label: label,
          width: track.width,
          height: track.height,
          copy?: true,
          video_bitrate: source_bit_rate,
          codecs: codecs,
          bandwidth: source_bit_rate * 2 + @audio_bandwidth_overhead,
          average_bandwidth: source_bit_rate + @audio_average_bandwidth_overhead
        }

      :error ->
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

  # The RFC 6381 codecs of H.264 video that can be copied, such as avc1.640029 for High 4.1
  defp copied_codecs(%VideoTrack{codec: "h264", profile: profile, level: level})
       when is_map_key(@copied_h264_profiles, profile) and is_integer(level) do
    level = level |> Integer.to_string(16) |> String.pad_leading(2, "0") |> String.downcase()
    {:ok, "avc1.#{@copied_h264_profiles[profile]}#{level}"}
  end

  defp copied_codecs(%VideoTrack{}), do: :error

  # Encoded as H.264 Main
  defp encoded(rung, track) do
    %Quality{
      id: rung.id,
      label: rung.label,
      width: scaled_width(rung.height, track.width, track.height),
      height: rung.height,
      copy?: false,
      video_bitrate: rung.video_bitrate,
      codecs: "avc1.4d401f",
      bandwidth: rung.video_bitrate + @audio_bandwidth_overhead,
      average_bandwidth: rung.video_bitrate + @audio_average_bandwidth_overhead
    }
  end

  defp scaled_width(height, source_width, source_height) do
    width = round(source_width * height / source_height)

    if rem(width, 2) == 0, do: width, else: width + 1
  end
end
