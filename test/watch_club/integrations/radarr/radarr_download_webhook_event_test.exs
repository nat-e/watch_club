defmodule WatchClub.Integrations.Radarr.RadarrDownloadWebhookEventTest do
  use ExUnit.Case, async: true

  alias WatchClub.Integrations.Radarr.RadarrDownloadWebhookEvent
  alias WatchClub.Integrations.Servarr.Webhook.MediaFile

  test "parses a Download payload into a typed struct" do
    event =
      RadarrDownloadWebhookEvent.from_api(%{
        "eventType" => "Download",
        "movie" => %{
          "tmdbId" => 11,
          "imdbId" => "tt0076759",
          "title" => "Star Wars",
          "year" => 1977,
          "folderPath" => "/movies/Star Wars (1977)"
        },
        "movieFile" => %{
          "relativePath" => "movie.mkv",
          "path" => "/movies/Star Wars (1977)/movie.mkv"
        },
        "isUpgrade" => true
      })

    assert %RadarrDownloadWebhookEvent{
             tmdb_id: 11,
             imdb_id: "tt0076759",
             title: "Star Wars",
             year: 1977,
             folder_path: "/movies/Star Wars (1977)",
             file: %MediaFile{
               relative_path: "movie.mkv",
               path: "/movies/Star Wars (1977)/movie.mkv"
             },
             upgrade?: true
           } = event
  end

  test "blank imdbId becomes nil and a missing isUpgrade defaults to false" do
    event = RadarrDownloadWebhookEvent.from_api(%{"movie" => %{"imdbId" => ""}, "movieFile" => %{}})

    assert event.imdb_id == nil
    assert event.upgrade? == false
  end

  test "a missing movieFile yields a nil file" do
    assert %RadarrDownloadWebhookEvent{file: nil} =
             RadarrDownloadWebhookEvent.from_api(%{"movie" => %{}})
  end
end
