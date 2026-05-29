defmodule WatchClub.MediaSources.Import.Ingestor.MatchContentTest do
  use WatchClub.DataCase

  alias WatchClub.Contents.{Content, Movie, TvShow, TvShowEpisode}
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.{EpisodeIdentity, MatchResult, MovieIdentity}
  alias WatchClub.MediaSources.Import.Ingestor.MatchContent

  describe "apply/1 — movie" do
    test "matches a movie that already exists in the DB" do
      movie = seed_movie(tmdb_id: 11)
      candidate = candidate_with(%MovieIdentity{tmdb_id: 11})

      assert {:ok,
              %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}}} =
               MatchContent.apply(candidate)

      assert matched_id == movie.id
    end

    test "creates and matches a movie that does not exist" do
      stub_tmdb(fn _conn, path ->
        tmdb_id = path |> Path.basename() |> String.to_integer()
        Map.put(tmdb_fixture("movie_details_11"), "id", tmdb_id)
      end)

      candidate = candidate_with(%MovieIdentity{tmdb_id: 11})

      assert {:ok,
              %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}}} =
               MatchContent.apply(candidate)

      assert is_binary(matched_id)
    end

    test "matches by IMDB id" do
      movie = seed_movie(tmdb_id: 11)

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/find/tt0076759")
        %{"movie_results" => [%{"id" => 11}]}
      end)

      candidate = candidate_with(%MovieIdentity{imdb_id: "tt0076759"})

      assert {:ok,
              %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}}} =
               MatchContent.apply(candidate)

      assert matched_id == movie.id
    end

    test "matches by title and year" do
      movie = seed_movie(tmdb_id: 11)

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/search/movie")
        %{"results" => [%{"id" => 11}]}
      end)

      candidate = candidate_with(%MovieIdentity{title: "Star Wars", year: 1977})

      assert {:ok,
              %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}}} =
               MatchContent.apply(candidate)

      assert matched_id == movie.id
    end

    test "passes through with matched_id: nil when no movie strategy matches" do
      candidate = candidate_with(%MovieIdentity{})

      assert {:ok, %Candidate{match_result: %MatchResult{result: :not_matched, matched_id: nil}}} =
               MatchContent.apply(candidate)
    end

    test "passes through with matched_id: nil when TMDB title search returns no results" do
      stub_tmdb(fn _conn, _path -> %{"results" => []} end)

      candidate = candidate_with(%MovieIdentity{title: "Unknown Film", year: 1999})

      assert {:ok, %Candidate{match_result: %MatchResult{result: :not_matched, matched_id: nil}}} =
               MatchContent.apply(candidate)
    end

    test "halts when TMDB returns an HTTP error" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Plug.Conn.send_resp(conn, 503, "")
      end)

      candidate = candidate_with(%MovieIdentity{imdb_id: "tt0076759"})

      assert {:halt, _} = MatchContent.apply(candidate)
    end
  end

  describe "apply/1 — tv episode" do
    test "matches an episode whose show already exists in the DB" do
      %{episode: episode} = seed_tv_show(tmdb_id: 1668, season: 1, episode: 3)

      candidate =
        candidate_with(%EpisodeIdentity{tmdb_id: 1668, season_number: 1, episode_number: 3})

      assert {:ok,
              %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}}} =
               MatchContent.apply(candidate)

      assert matched_id == episode.id
    end

    test "creates and matches an episode whose show does not exist" do
      stub_tmdb(fn _conn, _path ->
        tmdb_fixture("tv_details_1668")
      end)

      candidate =
        candidate_with(%EpisodeIdentity{tmdb_id: 1668, season_number: 1, episode_number: 3})

      assert {:ok,
              %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}}} =
               MatchContent.apply(candidate)

      assert is_binary(matched_id)
    end

    test "matches by show's TVDB id" do
      %{episode: episode} = seed_tv_show(tmdb_id: 1668, season: 1, episode: 3)

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/find/79168")
        %{"tv_results" => [%{"id" => 1668}]}
      end)

      candidate =
        candidate_with(%EpisodeIdentity{tvdb_id: 79168, season_number: 1, episode_number: 3})

      assert {:ok,
              %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}}} =
               MatchContent.apply(candidate)

      assert matched_id == episode.id
    end

    test "matches by show's IMDB id" do
      %{episode: episode} = seed_tv_show(tmdb_id: 1668, season: 1, episode: 3)

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/find/tt0108778")
        %{"tv_results" => [%{"id" => 1668}]}
      end)

      candidate =
        candidate_with(%EpisodeIdentity{
          imdb_id: "tt0108778",
          season_number: 1,
          episode_number: 3
        })

      assert {:ok,
              %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}}} =
               MatchContent.apply(candidate)

      assert matched_id == episode.id
    end

    test "matches by show title search" do
      %{episode: episode} = seed_tv_show(tmdb_id: 1668, season: 1, episode: 3)

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/search/tv")
        %{"results" => [%{"id" => 1668}]}
      end)

      candidate =
        candidate_with(%EpisodeIdentity{title: "Friends", season_number: 1, episode_number: 3})

      assert {:ok,
              %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}}} =
               MatchContent.apply(candidate)

      assert matched_id == episode.id
    end

    test "passes through with matched_id: nil when the show resolves but season/episode is missing" do
      _ = seed_tv_show(tmdb_id: 1668, season: 1, episode: 3)

      candidate =
        candidate_with(%EpisodeIdentity{tmdb_id: 1668, season_number: 99, episode_number: 99})

      assert {:ok, %Candidate{match_result: %MatchResult{result: :not_matched, matched_id: nil}}} =
               MatchContent.apply(candidate)
    end

    test "passes through with matched_id: nil when no TV strategy matches" do
      candidate = candidate_with(%EpisodeIdentity{season_number: 1, episode_number: 3})

      assert {:ok, %Candidate{match_result: %MatchResult{result: :not_matched, matched_id: nil}}} =
               MatchContent.apply(candidate)
    end
  end

  defp candidate_with(identity) do
    %Candidate{path: "/library/file.mkv", identity: identity}
  end

  defp stub_tmdb(response_fun) do
    Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
      Req.Test.json(conn, response_fun.(conn, conn.request_path))
    end)
  end

  defp seed_movie(tmdb_id: tmdb_id) do
    unique = System.unique_integer([:positive])

    content =
      Ash.Seed.seed!(Content, %{
        type: :movie,
        external_id_source: :tmdb,
        external_id: to_string(tmdb_id),
        original_title: "Movie #{unique}",
        original_language: "en",
        origin_country: "US"
      })

    Ash.Seed.seed!(Movie, %{id: content.id})
    content
  end

  defp seed_tv_show(tmdb_id: tmdb_id, season: season_number, episode: episode_number) do
    unique = System.unique_integer([:positive])

    content =
      Ash.Seed.seed!(Content, %{
        type: :tv_show,
        external_id_source: :tmdb,
        external_id: to_string(tmdb_id),
        original_title: "Show #{unique}",
        original_language: "en",
        origin_country: "US"
      })

    tv_show =
      Ash.Seed.seed!(TvShow, %{
        id: content.id,
        original_name: "Show #{unique}",
        tmdb_id: tmdb_id,
        tvdb_id: 79168
      })

    episode =
      Ash.Seed.seed!(TvShowEpisode, %{
        tv_show_id: tv_show.id,
        season_number: season_number,
        episode_number: episode_number
      })

    %{content: content, tv_show: tv_show, episode: episode}
  end
end
