defmodule WatchClub.Integrations.Sonarr.SonarrDownloadWebhookEventTest do
  use ExUnit.Case, async: true

  alias WatchClub.Integrations.Servarr.Webhook.MediaFile
  alias WatchClub.Integrations.Sonarr.SonarrDownloadWebhookEvent
  alias WatchClub.Integrations.Sonarr.SonarrDownloadWebhookEvent.Episode

  test "parses a multi-episode Download payload into a typed struct" do
    event =
      SonarrDownloadWebhookEvent.from_api(%{
        "eventType" => "Download",
        "series" => %{
          "tvdbId" => 79168,
          "tmdbId" => 1668,
          "imdbId" => "tt0108778",
          "title" => "Friends",
          "path" => "/tv/Friends"
        },
        "episodes" => [
          %{"seasonNumber" => 1, "episodeNumber" => 1},
          %{"seasonNumber" => 1, "episodeNumber" => 2}
        ],
        "episodeFile" => %{
          "relativePath" => "Season 01/friends.mkv",
          "path" => "/downloads/x.mkv"
        }
      })

    assert %SonarrDownloadWebhookEvent{
             tvdb_id: 79168,
             tmdb_id: 1668,
             imdb_id: "tt0108778",
             title: "Friends",
             series_path: "/tv/Friends",
             file: %MediaFile{relative_path: "Season 01/friends.mkv"},
             episodes: [
               %Episode{season_number: 1, episode_number: 1},
               %Episode{season_number: 1, episode_number: 2}
             ]
           } = event
  end

  test "missing episodes and episodeFile yield an empty list and a nil file" do
    event = SonarrDownloadWebhookEvent.from_api(%{"series" => %{}})

    assert event.episodes == []
    assert event.file == nil
  end
end
