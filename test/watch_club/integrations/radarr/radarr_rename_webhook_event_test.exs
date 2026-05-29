defmodule WatchClub.Integrations.Radarr.RadarrRenameWebhookEventTest do
  use ExUnit.Case, async: true

  alias WatchClub.Integrations.Radarr.RadarrRenameWebhookEvent
  alias WatchClub.Integrations.Servarr.Webhook.RenamedFile

  test "parses a Rename payload into a typed struct" do
    event =
      RadarrRenameWebhookEvent.from_api(%{
        "eventType" => "Rename",
        "movie" => %{"folderPath" => "/movies/EO (2022)"},
        "renamedMovieFiles" => [
          %{"previousPath" => "/movies/EO (2022)/old.mkv", "relativePath" => "EO (2022).mkv"}
        ]
      })

    assert %RadarrRenameWebhookEvent{
             folder_path: "/movies/EO (2022)",
             renamed_files: [
               %RenamedFile{
                 previous_path: "/movies/EO (2022)/old.mkv",
                 relative_path: "EO (2022).mkv"
               }
             ]
           } = event
  end

  test "missing renamedMovieFiles yields an empty list" do
    assert %RadarrRenameWebhookEvent{renamed_files: []} =
             RadarrRenameWebhookEvent.from_api(%{"movie" => %{}})
  end
end
