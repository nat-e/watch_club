defmodule WatchClub.Integrations.Radarr.RadarrMovieFileDeleteWebhookEventTest do
  use ExUnit.Case, async: true

  alias WatchClub.Integrations.Radarr.RadarrMovieFileDeleteWebhookEvent
  alias WatchClub.Integrations.Servarr.Webhook.MediaFile

  test "parses a MovieFileDelete payload into a typed struct" do
    event =
      RadarrMovieFileDeleteWebhookEvent.from_api(%{
        "eventType" => "MovieFileDelete",
        "deleteReason" => "manual",
        "movie" => %{"folderPath" => "/movies/EO (2022)"},
        "movieFile" => %{"relativePath" => "eo.mkv", "path" => "/movies/EO (2022)/eo.mkv"}
      })

    assert %RadarrMovieFileDeleteWebhookEvent{
             folder_path: "/movies/EO (2022)",
             file: %MediaFile{relative_path: "eo.mkv", path: "/movies/EO (2022)/eo.mkv"}
           } = event
  end

  test "a missing movieFile yields a nil file" do
    assert %RadarrMovieFileDeleteWebhookEvent{file: nil} =
             RadarrMovieFileDeleteWebhookEvent.from_api(%{"movie" => %{}})
  end
end
