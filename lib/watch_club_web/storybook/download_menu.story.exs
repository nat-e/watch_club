defmodule WatchClubWeb.Storybook.DownloadMenu do
  use PhoenixStorybook.Story, :component

  alias WatchClub.MediaCatalog.{Media, Part, Video, VideoTrack}
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
        description: "One file: the trigger downloads it straight away",
        attributes: %{
          id: "download-one",
          parts: [part(1, [video("Dune Part Two (2024) [Bluray-1080p].mkv", :hd_1080p)])]
        },
        slots: [trigger("download-one-trigger")]
      },
      %Variation{
        id: :several_videos,
        description: "Copies: the trigger opens a menu, where long file names wrap",
        attributes: %{
          id: "download-several",
          parts: [
            part(1, [
              video(
                "Dune.Part.Two.2024.2160p.UHD.BluRay.REMUX.DV.HDR.HEVC.TrueHD.Atmos.7.1-GROUP.mkv",
                :uhd_4k
              ),
              video("Dune Part Two (2024) [Bluray-1080p].mkv", :hd_1080p),
              video("Dune Part Two (2024).mp4", nil)
            ])
          ]
        },
        slots: [trigger("download-several-trigger")]
      },
      %Variation{
        id: :parts,
        description: "Parts: each file is named by the Part it holds",
        attributes: %{
          id: "download-parts",
          parts: [
            part(1, [
              video("The Office (US) - S04E01 - Fun Run (1) [WEBDL-1080p].mkv", :hd_1080p)
            ]),
            part(2, [
              video("The Office (US) - S04E02 - Fun Run (2) [WEBDL-1080p].mkv", :hd_1080p)
            ])
          ]
        },
        slots: [trigger("download-parts-trigger")]
      }
    ]
  end

  defp part(number, videos), do: %Part{id: Ash.UUIDv7.generate(), number: number, videos: videos}

  defp video(file_name, resolution) do
    %Video{
      id: Ash.UUIDv7.generate(),
      media: %Media{path: "/media/#{file_name}"},
      default_video_track: resolution && %VideoTrack{resolution: resolution}
    }
  end

  defp trigger(id) do
    ~s(<:trigger :let={download_link}><.button id="#{id}" variant="secondary" {download_link}><:icon><Lucideicons.download /></:icon>Download</.button></:trigger>)
  end
end
