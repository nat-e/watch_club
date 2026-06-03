defmodule WatchClub.Requests.ContentRequestTest do
  @moduledoc """
  Verifies the derived read model (status / progress?) — the
  multi-hop aggregate + cond SQL — actually executes and resolves correctly.
  Data is seeded directly to exercise the calculations without the
  TMDB-backed create flow.
  """
  use WatchClub.DataCase, async: true

  import WatchClub.Generator

  alias WatchClub.Contents.{Content, Movie, TvShow}
  alias WatchClub.MediaSources.{Servarr, Source}
  alias WatchClub.Requests
  alias WatchClub.Requests.{ContentRequest, MediaSourceRequest}
  alias WatchClub.Requests.Workers.SubmitMediaSourceRequest

  setup do
    user = generate(user())
    content = seed_content(:movie)
    request = Ash.Seed.seed!(ContentRequest, %{user_id: user.id, content_id: content.id})

    %{user: user, content: content, request: request, source: generate(media_source())}
  end

  defp load(request, user),
    do: Ash.load!(request, [:status, :progress], actor: user)

  # The `for_current_user` action loads content through `:for_view`, which
  # resolves `implementation` from the movie/tv_show row. Seed that row
  # directly (no TMDB) so the read model can resolve it; it shares the id.
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

  defp seed_request(content, source, state) do
    Ash.Seed.seed!(MediaSourceRequest, %{
      content_id: content.id,
      media_source_id: source.id,
      state: state,
      external_resource_id: System.unique_integer([:positive])
    })
  end

  test "a fresh request with no media source request reads as :requested", ctx do
    loaded = load(ctx.request, ctx.user)
    assert loaded.status == :requested
    assert loaded.progress == 0
  end

  test "a downloading request reads as :downloading", ctx do
    seed_request(ctx.content, ctx.source, :downloading)
    assert load(ctx.request, ctx.user).status == :downloading
  end

  test "a movie whose file imported but isn't ingested yet reads as :importing", ctx do
    seed_request(ctx.content, ctx.source, :downloaded)
    assert load(ctx.request, ctx.user).status == :importing
  end

  test "a show still fetching episodes (downloading) reads as :downloading", ctx do
    show = seed_content(:tv_show)
    request = Ash.Seed.seed!(ContentRequest, %{user_id: ctx.user.id, content_id: show.id})
    seed_request(show, ctx.source, :downloading)
    assert load(request, ctx.user).status == :downloading
  end

  test "a show whose queue drained (downloaded) reads as :importing until Media lands", ctx do
    show = seed_content(:tv_show)
    request = Ash.Seed.seed!(ContentRequest, %{user_id: ctx.user.id, content_id: show.id})
    seed_request(show, ctx.source, :downloaded)
    assert load(request, ctx.user).status == :importing
  end

  test "a partially-downloaded show reads as :downloading", ctx do
    show = seed_content(:tv_show)
    request = Ash.Seed.seed!(ContentRequest, %{user_id: ctx.user.id, content_id: show.id})
    seed_request(show, ctx.source, :partially_downloaded)
    assert load(request, ctx.user).status == :downloading
  end

  test "a needs_attention request reads as :failed", ctx do
    seed_request(ctx.content, ctx.source, :needs_attention)
    assert load(ctx.request, ctx.user).status == :failed
  end

  test "a not_released request reads as :not_released", ctx do
    seed_request(ctx.content, ctx.source, :not_released)
    assert load(ctx.request, ctx.user).status == :not_released
  end

  test "not_released outranks a sibling fresh requested", ctx do
    seed_request(ctx.content, ctx.source, :not_released)
    seed_request(ctx.content, generate(media_source()), :submitted)
    assert load(ctx.request, ctx.user).status == :not_released
  end

  test "best request wins: downloading beats a sibling needs_attention", ctx do
    seed_request(ctx.content, ctx.source, :needs_attention)
    seed_request(ctx.content, generate(media_source()), :downloading)
    assert load(ctx.request, ctx.user).status == :downloading
  end

  describe "for_current_user" do
    test "scopes to the actor and filters by the derived status group", ctx do
      # ctx.request (movie, no MSR) reads as :requested → in the in_progress group.
      other = generate(user())

      other_content =
        Ash.Seed.seed!(Content, %{
          type: :movie,
          external_id_source: :tmdb,
          external_id: "#{System.unique_integer([:positive])}",
          original_title: "Other",
          original_language: "en",
          origin_country: "US"
        })

      Ash.Seed.seed!(ContentRequest, %{user_id: other.id, content_id: other_content.id})

      assert ctx.user |> list_for(status_group: :in_progress) |> Enum.map(& &1.id) ==
               [ctx.request.id]

      assert list_for(ctx.user, status_group: :completed) == []
    end
  end

  defp list_for(user, args) do
    WatchClub.Requests.ContentRequest
    |> Ash.Query.for_read(:for_current_user, Map.new(args), actor: user)
    |> Ash.read!()
  end

  describe "request" do
    test "fans out one submit job per request-capable source for the content", ctx do
      source = seed_radarr_source()
      # Content already exists, so EnsureContentExists resolves it without TMDB.
      content = seed_content(:movie)

      assert {:ok, _request} =
               Requests.request_content(
                 %{
                   external_id_source: :tmdb,
                   external_id: content.external_id,
                   content_type: :movie
                 },
                 actor: ctx.user
               )

      assert_enqueued(
        worker: SubmitMediaSourceRequest,
        args: %{content_id: content.id, media_source_id: source.id}
      )
    end
  end

  defp seed_radarr_source do
    source = Ash.Seed.seed!(Source, %{source_type: :radarr, media_type: :movie, name: "radarr"})

    Ash.Seed.seed!(Servarr, %{
      id: source.id,
      flavor: :radarr,
      base_url: "http://radarr.test",
      api_key: "key",
      quality_profile_id: 4,
      quality_profile_name: "HD-1080p",
      root_folder_path: "/movies",
      local_root_folder_path: "/data/movies",
      webhook_callback_base_url: "http://watchclub.test",
      webhook_secret: "secret",
      notification_id: 1
    })

    source
  end

  describe "for_current_user pagination" do
    test "keyset-paginates across the derived last_activity sort", ctx do
      # ctx.request is the first; add two more so the page splits.
      [c2, c3] = [seed_content(:movie), seed_content(:tv_show)]
      r2 = Ash.Seed.seed!(ContentRequest, %{user_id: ctx.user.id, content_id: c2.id})
      r3 = Ash.Seed.seed!(ContentRequest, %{user_id: ctx.user.id, content_id: c3.id})

      page1 =
        ContentRequest
        |> Ash.Query.for_read(:for_current_user, %{}, actor: ctx.user)
        |> Ash.read!(page: [limit: 2])

      assert length(page1.results) == 2
      assert page1.more?

      after_keyset = List.last(page1.results).__metadata__.keyset

      page2 =
        ContentRequest
        |> Ash.Query.for_read(:for_current_user, %{}, actor: ctx.user)
        |> Ash.read!(page: [limit: 2, after: after_keyset])

      assert length(page2.results) == 1
      refute page2.more?

      ids = Enum.map(page1.results ++ page2.results, & &1.id)
      assert Enum.sort(ids) == Enum.sort([ctx.request.id, r2.id, r3.id])
    end
  end
end
