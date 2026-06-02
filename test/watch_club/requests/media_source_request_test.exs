defmodule WatchClub.Requests.MediaSourceRequestTest do
  @moduledoc """
  Exercises the `:create` action end-to-end: `RefreshState` derives the initial
  `state` from the *arr's current truth (resource + download queue), stubbed at
  the HTTP boundary. The series cases pin the cold-start fix — a just-added
  aired show whose Sonarr statistics aren't computed yet (`episode_count == 0`)
  derives `:submitted`, not `:not_released`; only a genuine `"upcoming"` status
  is not-released.
  """
  use WatchClub.DataCase, async: false

  alias WatchClub.Contents.Content
  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.{Servarr, Source}
  alias WatchClub.Requests
  alias WatchClub.SystemActor

  setup do
    previous = Application.get_env(:watch_club, :servarr_req_options)
    Application.put_env(:watch_club, :servarr_req_options, plug: {Req.Test, Client}, retry: false)
    on_exit(fn -> Application.put_env(:watch_club, :servarr_req_options, previous) end)
    :ok
  end

  defp create(source, content, external_resource_id \\ 1) do
    Requests.create_media_source_request!(
      %{
        content_id: content.id,
        media_source_id: source.id,
        external_resource_id: external_resource_id
      },
      actor: SystemActor.actor()
    )
  end

  # ── Sonarr ────────────────────────────────────────────────────────────────

  describe "create derives series state from Sonarr" do
    setup do
      %{source: seed_servarr_source(:sonarr, :tv_show_episode), content: seed_content(:tv_show)}
    end

    test "a just-added aired series with uncomputed stats is :submitted, not :not_released",
         ctx do
      stub_sonarr(series("ended", 0, 0), [])
      assert create(ctx.source, ctx.content).state == :submitted
    end

    test "a genuinely upcoming series is :not_released", ctx do
      stub_sonarr(series("upcoming", 0, 0), [])
      assert create(ctx.source, ctx.content).state == :not_released
    end

    test "a series with all aired episodes present is :downloaded", ctx do
      stub_sonarr(series("ended", 62, 62), [])
      assert create(ctx.source, ctx.content).state == :downloaded
    end

    test "a series with an active download queue is :downloading", ctx do
      stub_sonarr(series("continuing", 10, 2), [queue_item()])
      assert create(ctx.source, ctx.content).state == :downloading
    end
  end

  # ── Radarr ────────────────────────────────────────────────────────────────

  describe "create derives movie state from Radarr" do
    setup do
      %{source: seed_servarr_source(:radarr, :movie), content: seed_content(:movie)}
    end

    test "a movie not yet released is :not_released", ctx do
      stub_radarr(movie_json(%{"hasFile" => false, "isAvailable" => false}), [])
      assert create(ctx.source, ctx.content).state == :not_released
    end

    test "a movie whose file is present is :downloaded", ctx do
      stub_radarr(movie_json(%{"hasFile" => true}), [])
      assert create(ctx.source, ctx.content).state == :downloaded
    end
  end

  # ── Fixtures ────────────────────────────────────────────────────────────────

  defp seed_servarr_source(flavor, media_type) do
    source =
      Ash.Seed.seed!(Source, %{
        source_type: flavor,
        media_type: media_type,
        name: "#{flavor} source"
      })

    Ash.Seed.seed!(Servarr, %{
      id: source.id,
      flavor: flavor,
      base_url: "http://#{flavor}.test",
      api_key: "key",
      quality_profile_id: 6,
      quality_profile_name: "HD-1080p",
      root_folder_path: "/media",
      local_root_folder_path: "/data",
      webhook_callback_base_url: "http://watchclub.test",
      webhook_secret: "secret",
      notification_id: 1
    })

    source
  end

  defp seed_content(type) do
    Ash.Seed.seed!(Content, %{
      type: type,
      external_id_source: :tmdb,
      external_id: "#{System.unique_integer([:positive])}",
      original_title: "Seeded #{type}",
      original_language: "en",
      origin_country: "US"
    })
  end

  defp series(status, episode_count, episode_file_count) do
    %{
      "id" => 1,
      "title" => "Seeded show",
      "status" => status,
      "statistics" => %{"episodeCount" => episode_count, "episodeFileCount" => episode_file_count}
    }
  end

  defp movie_json(attrs) do
    Map.merge(
      %{"id" => 1, "title" => "Seeded movie", "hasFile" => false, "isAvailable" => true},
      attrs
    )
  end

  # A non-blocked, actively-downloading queue item.
  defp queue_item do
    %{
      "status" => "downloading",
      "trackedDownloadStatus" => "ok",
      "trackedDownloadState" => "downloading"
    }
  end

  # `RefreshState` makes two calls per derivation: the resource then its queue.
  defp stub_sonarr(series, queue) do
    Req.Test.stub(Client, fn conn ->
      case conn.request_path do
        "/api/v3/series/" <> _ -> Req.Test.json(conn, series)
        "/api/v3/queue/details" -> Req.Test.json(conn, queue)
      end
    end)
  end

  defp stub_radarr(movie, queue) do
    Req.Test.stub(Client, fn conn ->
      case conn.request_path do
        "/api/v3/movie/" <> _ -> Req.Test.json(conn, movie)
        "/api/v3/queue/details" -> Req.Test.json(conn, queue)
      end
    end)
  end
end
