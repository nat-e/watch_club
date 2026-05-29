defmodule WatchClub.Integrations.Sonarr.SonarrRenameWebhookEventTest do
  use ExUnit.Case, async: true

  alias WatchClub.Integrations.Servarr.Webhook.RenamedFile
  alias WatchClub.Integrations.Sonarr.SonarrRenameWebhookEvent

  test "parses a Rename payload into a typed struct" do
    event =
      SonarrRenameWebhookEvent.from_api(%{
        "eventType" => "Rename",
        "series" => %{"path" => "/tv/Friends"},
        "renamedEpisodeFiles" => [
          %{
            "previousPath" => "/tv/Friends/Season 01/old.mkv",
            "relativePath" => "Season 01/friends-s01e01.mkv"
          }
        ]
      })

    assert %SonarrRenameWebhookEvent{
             series_path: "/tv/Friends",
             renamed_files: [
               %RenamedFile{
                 previous_path: "/tv/Friends/Season 01/old.mkv",
                 relative_path: "Season 01/friends-s01e01.mkv"
               }
             ]
           } = event
  end

  test "missing renamedEpisodeFiles yields an empty list" do
    assert %SonarrRenameWebhookEvent{renamed_files: []} =
             SonarrRenameWebhookEvent.from_api(%{"series" => %{}})
  end
end
