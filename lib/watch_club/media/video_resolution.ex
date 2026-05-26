defmodule WatchClub.Media.VideoResolution do
  @moduledoc """
  Bucketed display resolution for a `VideoTrack`. Values are ordered from
  lowest to highest so `Enum.max_by/2` on the `rank/1` helper picks the
  dominant track when multiple are present.
  """

  use Ash.Type.Enum,
    values: [
      sd: [description: "Standard definition (≤ 576p)"],
      hd_720p: [description: "720p HD"],
      hd_1080p: [description: "1080p Full HD"],
      uhd_4k: [description: "4K Ultra HD"]
    ]

  def label(:uhd_4k), do: "4K"
  def label(:hd_1080p), do: "1080p"
  def label(:hd_720p), do: "720p"
  def label(:sd), do: "SD"
  def label(_), do: nil

  def rank(:uhd_4k), do: 3
  def rank(:hd_1080p), do: 2
  def rank(:hd_720p), do: 1
  def rank(:sd), do: 0
end
