defmodule WatchClubWeb.Components.Medias.VideoResolutionBadge do
  @moduledoc """
  Renders the bucketed display resolution of a `Video` as a muted badge.

  Reads the resolution from the video's `:default_video_track` (which must be
  loaded). Falls back to an em dash when the video has no tracks or no
  detectable resolution.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.UI.Badge

  alias WatchClub.MediaCatalog.{Video, VideoResolution}

  attr :video, Video, default: nil
  attr :size, :string, values: ~w(sm md), default: "md"
  attr :class, :any, default: nil

  def video_resolution_badge(assigns) do
    assigns = assign(assigns, :bucket, bucket(assigns.video))

    ~H"""
    <.badge :if={@bucket} variant="muted" size={@size} class={@class}>
      {VideoResolution.label(@bucket)}
    </.badge>
    <span :if={!@bucket} class={["text-text-subtle", @class]}>—</span>
    """
  end

  defp bucket(%Video{default_video_track: %{resolution: bucket}}), do: bucket
  defp bucket(_), do: nil
end
