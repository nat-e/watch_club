defmodule WatchClub.Integrations.Sonarr.SonarrEpisodeFileDeleteWebhookEventTest do
  use ExUnit.Case, async: true

  alias WatchClub.Integrations.Servarr.Webhook.MediaFile
  alias WatchClub.Integrations.Sonarr.SonarrEpisodeFileDeleteWebhookEvent

  test "parses an EpisodeFileDelete payload into a typed struct" do
    event =
      SonarrEpisodeFileDeleteWebhookEvent.from_api(%{
        "eventType" => "EpisodeFileDelete",
        "deleteReason" => "manual",
        "series" => %{"path" => "/tv/Friends"},
        "episodeFile" => %{
          "relativePath" => "Season 01/friends.mkv",
          "path" => "/tv/Friends/Season 01/friends.mkv"
        }
      })

    assert %SonarrEpisodeFileDeleteWebhookEvent{
             series_path: "/tv/Friends",
             file: %MediaFile{
               relative_path: "Season 01/friends.mkv",
               path: "/tv/Friends/Season 01/friends.mkv"
             }
           } = event
  end

  test "a missing episodeFile yields a nil file" do
    assert %SonarrEpisodeFileDeleteWebhookEvent{file: nil} =
             SonarrEpisodeFileDeleteWebhookEvent.from_api(%{"series" => %{}})
  end
end
