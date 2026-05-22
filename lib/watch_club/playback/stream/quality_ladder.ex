defmodule WatchClub.Playback.Stream.QualityLadder do
  @moduledoc """
  Builds the list of HLS variants offered for a source video.

  The ladder always includes an "original" variant capped at the source
  bitrate, and adds 720p / 480p / 360p rungs as long as the source is at
  least that tall. Each rung carries the encoded width, height, target
  video bitrate, and the bandwidth values exposed in the master playlist.
  """

  defmodule Quality do
    @moduledoc false
    @enforce_keys [:id, :label, :width, :height, :video_bitrate, :bandwidth, :average_bandwidth]
    defstruct [:id, :label, :width, :height, :video_bitrate, :bandwidth, :average_bandwidth]

    @type t :: %__MODULE__{
            id: String.t(),
            label: String.t(),
            width: integer(),
            height: integer(),
            video_bitrate: integer(),
            bandwidth: integer(),
            average_bandwidth: integer()
          }
  end

  @audio_bandwidth_overhead 192_000
  @audio_average_bandwidth_overhead 160_000
  @default_source_bit_rate 2_500_000
  @min_original_bitrate 3_500_000
  @max_original_bitrate 6_500_000

  @spec build(integer(), integer(), integer() | nil) :: [Quality.t()]
  def build(source_width, source_height, source_bit_rate) do
    source_bit_rate = source_bit_rate || @default_source_bit_rate

    original_bitrate =
      (source_bit_rate * 2)
      |> max(@min_original_bitrate)
      |> min(@max_original_bitrate)

    [
      %{
        id: "original",
        label: "Original (#{source_height}p)",
        height: source_height,
        video_bitrate: original_bitrate
      },
      %{id: "720p", label: "720p", height: 720, video_bitrate: 2_800_000},
      %{id: "480p", label: "480p", height: 480, video_bitrate: 1_400_000},
      %{id: "360p", label: "360p", height: 360, video_bitrate: 800_000}
    ]
    |> Enum.map(fn rung -> %{rung | height: min(rung.height, source_height)} end)
    |> Enum.uniq_by(& &1.height)
    |> Enum.map(fn rung ->
      width = scaled_width(rung.height, source_width, source_height)

      %Quality{
        id: rung.id,
        label: rung.label,
        width: width,
        height: rung.height,
        video_bitrate: rung.video_bitrate,
        bandwidth: rung.video_bitrate + @audio_bandwidth_overhead,
        average_bandwidth: rung.video_bitrate + @audio_average_bandwidth_overhead
      }
    end)
  end

  defp scaled_width(height, source_width, source_height) do
    width = round(source_width * height / source_height)

    if rem(width, 2) == 0, do: width, else: width + 1
  end
end
