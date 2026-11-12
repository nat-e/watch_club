defmodule WatchClub.Requests.MediaSourceRequestTest do
  @moduledoc """
  Exercises the `:create` action end-to-end: creating a request schedules
  `RefreshMediaSourceRequest`, which derives the `status` from the *arr's
  current truth (episodes or movie + download queue), stubbed at the HTTP
  boundary.
  """
  use WatchClub.DataCase, async: false

  alias WatchClub.Contents.{Content, Movie, TvShow}
  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.{Servarr, Source}
  alias WatchClub.Requests
  alias WatchClub.Requests.MediaSourceRequest
  alias WatchClub.Requests.Workers.RefreshMediaSourceRequest
  alias WatchClub.SystemActor

  setup do
    previous = Application.get_env(:watch_club, :servarr_req_options)
    Application.put_env(:watch_club, :servarr_req_options, plug: {Req.Test, Client})
    on_exit(fn -> Application.put_env(:watch_club, :servarr_req_options, previous) end)
    :ok
  end

  defp create_and_refresh(source, content) do
    request =
      Requests.create_media_source_request!(
        %{content_id: content.id, media_source_id: source.id, external_resource_id: 1},
        actor: SystemActor.actor()
      )

    Oban.drain_queue(queue: :media_source_requests, with_scheduled: true)

    Ash.get!(MediaSourceRequest, request.id, actor: SystemActor.actor())
  end

  # ── Sonarr ────────────────────────────────────────────────────────────────

  describe "create derives series status from Sonarr" do
    setup do
      %{source: seed_servarr_source(:sonarr, :tv_show_episode), content: seed_content(:tv_show)}
    end

    test "a just-added series with no episodes yet is :searching, not :not_released", ctx do
      stub_sonarr([], [])
      assert create_and_refresh(ctx.source, ctx.content).status == :searching
    end

    test "a series whose episodes have all yet to air is :not_released", ctx do
      stub_sonarr([episode(%{"airDateUtc" => "2999-01-01T00:00:00Z"})], [])
      assert create_and_refresh(ctx.source, ctx.content).status == :not_released
    end

    test "a series with all episodes present is :downloaded", ctx do
      stub_sonarr([episode(%{"hasFile" => true}), episode(%{"hasFile" => true})], [])
      assert create_and_refresh(ctx.source, ctx.content).status == :downloaded
    end

    test "a series with every aired regular episode present is :downloaded, whatever its specials and unaired episodes",
         ctx do
      stub_sonarr(
        [
          episode(%{"hasFile" => true}),
          episode(%{"seasonNumber" => 0}),
          episode(%{"airDateUtc" => "2999-01-01T00:00:00Z"})
        ],
        []
      )

      assert create_and_refresh(ctx.source, ctx.content).status == :downloaded
    end

    test "a series with an active download queue is :downloading", ctx do
      stub_sonarr([episode(%{"id" => 1, "hasFile" => false})], [queue_item()])
      assert create_and_refresh(ctx.source, ctx.content).status == :downloading
    end
  end

  # ── Radarr ────────────────────────────────────────────────────────────────

  describe "create derives movie status from Radarr" do
    setup do
      %{source: seed_servarr_source(:radarr, :movie), content: seed_content(:movie)}
    end

    test "a movie not yet released is :not_released", ctx do
      stub_radarr(movie_json(%{"hasFile" => false, "isAvailable" => false}), [])
      assert create_and_refresh(ctx.source, ctx.content).status == :not_released
    end

    test "a movie whose file is present is :downloaded", ctx do
      stub_radarr(movie_json(%{"hasFile" => true}), [])
      assert create_and_refresh(ctx.source, ctx.content).status == :downloaded
    end
  end

  describe "destroy_media_source_request/2" do
    test "ends the request's scheduled refresh" do
      request =
        generate(media_source_request(generate(movie()), seed_servarr_source(:radarr, :movie)))

      request.id |> RefreshMediaSourceRequest.new_job() |> Oban.insert!()

      Requests.destroy_media_source_request!(request, actor: SystemActor.actor())

      assert %{success: 1, failure: 0} =
               Oban.drain_queue(queue: :media_source_requests, with_scheduled: true)
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
    content =
      Ash.Seed.seed!(Content, %{
        type: type,
        external_id_source: :tmdb,
        external_id: "#{System.unique_integer([:positive])}",
        original_title: "Seeded #{type}",
        original_language: "en",
        origin_country: "US"
      })

    seed_implementation(type, content.id)
    content
  end

  defp seed_implementation(:movie, id), do: Ash.Seed.seed!(Movie, %{id: id})

  defp seed_implementation(:tv_show, id) do
    Ash.Seed.seed!(TvShow, %{
      id: id,
      original_name: "Seeded show",
      tmdb_id: System.unique_integer([:positive]),
      tvdb_id: System.unique_integer([:positive])
    })
  end

  defp episode(attrs) do
    Map.merge(
      %{
        "id" => System.unique_integer([:positive]),
        "seriesId" => 1,
        "seasonNumber" => 1,
        "episodeNumber" => 1,
        "hasFile" => false,
        "airDateUtc" => "2020-01-01T00:00:00Z"
      },
      attrs
    )
  end

  defp movie_json(attrs) do
    Map.merge(
      %{"id" => 1, "title" => "Seeded movie", "hasFile" => false, "isAvailable" => true},
      attrs
    )
  end

  # A non-blocked, actively-downloading queue item.
  defp queue_item do
    %{"episodeId" => 1, "status" => "downloading", "size" => 100, "sizeleft" => 50}
  end

  # A refresh makes two calls: the resource then its queue.
  defp stub_sonarr(episodes, queue) do
    Req.Test.stub(Client, fn conn ->
      case conn.request_path do
        "/api/v3/episode" -> Req.Test.json(conn, episodes)
        "/api/v3/queue/details" -> Req.Test.json(conn, queue)
        "/api/v3/command" -> Req.Test.json(conn, %{})
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
