defmodule WatchClubWeb.Storybook.VideoDownload do
  use PhoenixStorybook.Story, :component

  alias WatchClub.MediaCatalog.{Media, Video, VideoTrack}
  alias WatchClubWeb.Components.Medias.VideoDownload

  def function, do: &VideoDownload.video_download/1

  def imports do
    [
      {WatchClubWeb.Components.UI.Button, [button: 1]},
      {Lucideicons, [hard_drive_download: 1]}
    ]
  end

  def template do
    """
    <div class="flex min-h-64 items-start justify-center p-12 text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :one_video,
        description: "The only Video downloads at once",
        attributes: %{
          id: "download-one",
          locale: :en,
          videos: [video("1", "Gone Girl (2014) WEBDL-720p.mp4", 734_000_000, :hd_720p)]
        },
        slots: [trigger("download-one-button")]
      },
      %Variation{
        id: :several_videos,
        description: "Several Videos open a menu to choose one",
        attributes: %{
          id: "download-several",
          locale: :en,
          videos: [
            video("2", "John Wick (2014) Bluray-1080p.mkv", 8_200_000_000, :hd_1080p),
            video("3", "John Wick (2014) Remux-2160p.mkv", 41_500_000_000, :uhd_4k)
          ]
        },
        slots: [trigger("download-several-button")]
      },
      %Variation{
        id: :file_gone,
        description: "A Video whose file is gone is left out, in French",
        attributes: %{
          id: "download-gone",
          locale: :fr,
          videos: [
            video("4", "Amélie (2001) Bluray-1080p.mkv", 9_100_000_000, :hd_1080p),
            video("5", "Amélie (2001) DVD.mkv", nil, :sd)
          ]
        },
        slots: [trigger("download-gone-button")]
      }
    ]
  end

  defp trigger(id) do
    """
    <:trigger :let={attrs}>
      <.button id="#{id}" variant="ghost" size="icon" aria-label="Download" {attrs}>
        <Lucideicons.hard_drive_download />
      </.button>
    </:trigger>
    """
  end

  defp video(id, file_name, file_size, resolution) do
    %Video{
      id: id,
      default_video_track: %VideoTrack{resolution: resolution},
      media: %Media{file_name: file_name, file_size: file_size}
    }
  end
end
