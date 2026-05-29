defmodule WatchClub.MediaCatalog.VideoResolution do
  @moduledoc """
  Bucketed display resolution for a `VideoTrack`. Computed by the `:resolution`
  calculation on `VideoTrack`; rendered with `label/1`.
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
end
