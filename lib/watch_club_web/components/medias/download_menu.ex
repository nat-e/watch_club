defmodule WatchClubWeb.Components.Medias.DownloadMenu do
  @moduledoc """
  Download for the Videos of a Movie or a TV Show Episode. Its trigger downloads the only Video
  straight away, or opens a menu of the Videos, each named by its resolution and its file name.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Medias.VideoResolutionBadge

  attr :id, :string, required: true
  attr :videos, :list, required: true, doc: "with their `media` and `default_video_track`"

  slot :trigger,
    required: true,
    doc: "Gets the link attributes that download the only Video, or none when it opens the menu"

  def download_menu(%{videos: [video]} = assigns) do
    assigns = assign(assigns, :video, video)

    ~H"""
    {render_slot(@trigger, %{href: ~p"/media/#{@video.id}/download", download: true})}
    """
  end

  def download_menu(assigns) do
    ~H"""
    <.dropdown_menu id={@id}>
      <:trigger>{render_slot(@trigger, %{})}</:trigger>
      <.dropdown_menu_item
        :for={video <- @videos}
        id={"#{@id}-#{video.id}"}
        href={~p"/media/#{video.id}/download"}
        download
        class="max-w-80"
      >
        <.video_resolution_badge video={video} size="sm" class="shrink-0" />
        <span class="min-w-0 [overflow-wrap:anywhere]">{Path.basename(video.media.path)}</span>
      </.dropdown_menu_item>
    </.dropdown_menu>
    """
  end
end
