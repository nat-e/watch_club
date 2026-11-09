defmodule WatchClubWeb.Storybook.DownloadMenu do
  use PhoenixStorybook.Story, :component

  alias WatchClub.MediaCatalog.{Media, Video, VideoTrack}
  alias WatchClubWeb.Components.Medias.DownloadMenu

  def function, do: &DownloadMenu.download_menu/1

  def imports do
    [
      {WatchClubWeb.Components.UI.Button, [button: 1]},
      {Lucideicons, [download: 1]}
    ]
  end

  def template do
    """
    <div class="flex min-h-80 items-start justify-center p-12 text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :one_video,
        description: "A Movie with one Video",
        attributes: %{
          id: "download-one",
          videos: [video("Dune Part Two (2024) [Bluray-1080p].mkv", :hd_1080p)]
        },
        slots: [trigger("download-one-trigger")]
      },
      %Variation{
        id: :several_videos,
        description: "Several Videos, with long file names that wrap",
        attributes: %{
          id: "download-several",
          videos: [
            video(
              "Dune.Part.Two.2024.2160p.UHD.BluRay.REMUX.DV.HDR.HEVC.TrueHD.Atmos.7.1-GROUP.mkv",
              :uhd_4k
            ),
            video("Dune Part Two (2024) [Bluray-1080p].mkv", :hd_1080p),
            video("Dune Part Two (2024).mp4", nil)
          ]
        },
        slots: [trigger("download-several-trigger")]
      }
    ]
  end

  defp video(file_name, resolution) do
    %Video{
      id: Ash.UUIDv7.generate(),
      media: %Media{path: "/media/movies/Dune Part Two (2024)/#{file_name}"},
      default_video_track: resolution && %VideoTrack{resolution: resolution}
    }
  end

  defp trigger(id) do
    ~s(<:trigger><.button id="#{id}" variant="secondary"><:icon><Lucideicons.download /></:icon>Download</.button></:trigger>)
  end
end
