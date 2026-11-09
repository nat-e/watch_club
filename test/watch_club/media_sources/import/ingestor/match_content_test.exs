defmodule WatchClub.MediaSources.Import.Ingestor.MatchContentTest do
  use WatchClub.DataCase, async: false

  alias WatchClub.Contents.Content
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.{EpisodeIdentity, MatchResult, MovieIdentity}
  alias WatchClub.MediaSources.Import.Ingestor.MatchContent

  describe "apply/1" do
    test "matches a Movie refreshed under 15 minutes ago without HTTP requests" do
      movie =
        generate(
          movie(
            external_id: "11",
            metadata_refreshed_at: DateTime.add(DateTime.utc_now(), -14, :minute)
          )
        )

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn _conn ->
        flunk("a recently refreshed Movie must not make a TMDB request")
      end)

      candidate = candidate_with(%MovieIdentity{tmdb_id: 11})

      assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
               MatchContent.apply(candidate)

      assert matched_id == movie.id
    end

    test "creates and matches a movie that does not exist" do
      stub_tmdb(fn _conn, path ->
        tmdb_id = path |> Path.basename() |> String.to_integer()
        Map.put(tmdb_fixture("movie_details_11"), "id", tmdb_id)
      end)

      candidate = candidate_with(%MovieIdentity{tmdb_id: 11})

      assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
               MatchContent.apply(candidate)

      assert is_binary(matched_id)
    end

    test "refreshes a Movie older than 15 minutes and reuses it for later files" do
      movie =
        generate(
          movie(
            external_id: "11",
            metadata_refreshed_at: DateTime.add(DateTime.utc_now(), -16, :minute)
          )
        )

      parent = self()

      stub_tmdb(fn _conn, _path ->
        send(parent, :fetched_metadata)
        tmdb_fixture("movie_details_11")
      end)

      candidate = candidate_with(%MovieIdentity{tmdb_id: 11})

      for _ <- 1..2 do
        assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
                 MatchContent.apply(candidate)

        assert matched_id == movie.id
      end

      assert_receive :fetched_metadata
      assert_receive :fetched_metadata
      refute_receive :fetched_metadata, 0
    end

    test "matches by IMDB id" do
      movie = generate(movie(external_id: "11"))

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/find/tt0076759")
        %{"movie_results" => [%{"id" => 11}]}
      end)

      candidate = candidate_with(%MovieIdentity{imdb_id: "tt0076759"})

      assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
               MatchContent.apply(candidate)

      assert matched_id == movie.id
    end

    test "matches by title and year" do
      movie = generate(movie(external_id: "11"))

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/search/movie")
        %{"results" => [%{"id" => 11}]}
      end)

      candidate = candidate_with(%MovieIdentity{title: "Star Wars", year: 1977})

      assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
               MatchContent.apply(candidate)

      assert matched_id == movie.id
    end

    test "passes through with matched_id: nil when no movie strategy matches" do
      candidate = candidate_with(%MovieIdentity{})

      assert %Candidate{match_result: %MatchResult{result: :not_matched, matched_id: nil}} =
               MatchContent.apply(candidate)
    end

    test "passes through with matched_id: nil when TMDB title search returns no results" do
      stub_tmdb(fn _conn, _path -> %{"results" => []} end)

      candidate = candidate_with(%MovieIdentity{title: "Unknown Film", year: 1999})

      assert %Candidate{match_result: %MatchResult{result: :not_matched, matched_id: nil}} =
               MatchContent.apply(candidate)
    end

    test "raises when TMDB returns an HTTP error, so that the Oban job retries" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Plug.Conn.send_resp(conn, 503, "")
      end)

      candidate = candidate_with(%MovieIdentity{imdb_id: "tt0076759"})

      assert_raise MatchError, fn -> MatchContent.apply(candidate) end
    end

    test "matches a TV Show Episode refreshed under 15 minutes ago without HTTP requests" do
      show =
        generate(
          tv_show(
            external_id: "1668",
            num_seasons: 1,
            episodes_per_season: 3,
            metadata_refreshed_at: DateTime.add(DateTime.utc_now(), -14, :minute)
          )
        )

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn _conn ->
        flunk("a recently refreshed TV Show must not make a TMDB request")
      end)

      episode = Enum.find(show.tv_show.episodes, &(&1.episode_number == 3))

      candidate =
        candidate_with(%EpisodeIdentity{tmdb_id: 1668, season_number: 1, episode_number: 3})

      assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
               MatchContent.apply(candidate)

      assert matched_id == episode.id
    end

    test "creates and matches an episode whose show does not exist" do
      stub_tv_metadata(%{1 => [3]})

      candidate =
        candidate_with(%EpisodeIdentity{tmdb_id: 1668, season_number: 1, episode_number: 3})

      assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
               MatchContent.apply(candidate)

      assert is_binary(matched_id)
    end

    test "matches by show's TVDB id" do
      show = generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 3))
      episode = Enum.find(show.tv_show.episodes, &(&1.episode_number == 3))

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/find/79168")
        %{"tv_results" => [%{"id" => 1668}]}
      end)

      candidate =
        candidate_with(%EpisodeIdentity{tvdb_id: 79_168, season_number: 1, episode_number: 3})

      assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
               MatchContent.apply(candidate)

      assert matched_id == episode.id
    end

    test "matches by show's IMDB id" do
      show = generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 3))
      episode = Enum.find(show.tv_show.episodes, &(&1.episode_number == 3))

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

      assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
               MatchContent.apply(candidate)

      assert matched_id == episode.id
    end

    test "matches by show title search" do
      show = generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 3))
      episode = Enum.find(show.tv_show.episodes, &(&1.episode_number == 3))

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/search/tv")
        %{"results" => [%{"id" => 1668}]}
      end)

      candidate =
        candidate_with(%EpisodeIdentity{title: "Friends", season_number: 1, episode_number: 3})

      assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
               MatchContent.apply(candidate)

      assert matched_id == episode.id
    end

    test "matches a TV Show Episode added by TMDB after the TV Show was stored" do
      show =
        generate(
          tv_show(
            external_id: "1668",
            num_seasons: 1,
            episodes_per_season: 1,
            metadata_refreshed_at: DateTime.add(DateTime.utc_now(), -16, :minute)
          )
        )

      stub_tv_metadata(%{1 => [1, 2]})

      candidate =
        candidate_with(%EpisodeIdentity{tmdb_id: 1668, season_number: 1, episode_number: 2})

      assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
               MatchContent.apply(candidate)

      assert %{tv_show_id: show_id, season_number: 1, episode_number: 2} =
               Ash.get!(WatchClub.Contents.TvShowEpisode, matched_id)

      assert show_id == show.id
    end

    test "files from the same new season share one fetch and later files use stored metadata" do
      generate(
        tv_show(
          external_id: "1668",
          num_seasons: 1,
          episodes_per_season: 1,
          metadata_refreshed_at: DateTime.add(DateTime.utc_now(), -16, :minute)
        )
      )

      parent = self()

      stub_tv_metadata(%{1 => [1], 2 => [1, 2, 3]}, fn conn ->
        language = URI.decode_query(conn.query_string)["language"]
        send(parent, {:fetched_metadata, conn.request_path, language})

        if String.ends_with?(conn.request_path, "/tv/1668") and language == "en-US" do
          send(parent, {:fetch_started, self()})
          receive do: (:finish_fetch -> :ok)
        end
      end)

      callers =
        for number <- 1..3 do
          Task.async(fn ->
            MatchContent.apply(
              candidate_with(%EpisodeIdentity{
                tmdb_id: 1668,
                season_number: 2,
                episode_number: number
              })
            )
          end)
        end

      assert_receive {:fetch_started, fetch}
      await_metadata_callers(3)
      send(fetch, :finish_fetch)

      for candidate <- Task.await_many(callers) do
        assert %MatchResult{result: :success, matched_id: id} = candidate.match_result
        assert is_binary(id)
      end

      # Two Locales, each with the TV Show's details and its two seasons.
      for _ <- 1..6, do: assert_receive({:fetched_metadata, _, _})
      refute_receive {:fetched_metadata, _, _}, 0

      assert %Candidate{match_result: %MatchResult{result: :success}} =
               MatchContent.apply(
                 candidate_with(%EpisodeIdentity{
                   tmdb_id: 1668,
                   season_number: 2,
                   episode_number: 1
                 })
               )

      refute_receive {:fetched_metadata, _, _}, 0
    end

    test "matches a stored TV Show Episode when TMDB is unavailable during a refresh" do
      show =
        generate(
          tv_show(
            external_id: "1668",
            num_seasons: 1,
            episodes_per_season: 1,
            metadata_refreshed_at: DateTime.add(DateTime.utc_now(), -16, :minute)
          )
        )

      [episode] = show.tv_show.episodes

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Plug.Conn.send_resp(conn, 503, "")
      end)

      assert %Candidate{match_result: %MatchResult{result: :success, matched_id: matched_id}} =
               MatchContent.apply(
                 candidate_with(%EpisodeIdentity{
                   tmdb_id: 1668,
                   season_number: 1,
                   episode_number: 1
                 })
               )

      assert matched_id == episode.id
      assert Ash.get!(Content, show.id).metadata_refreshed_at == show.metadata_refreshed_at
    end

    test "raises when TMDB still does not list the file's TV Show Episode" do
      generate(
        tv_show(
          external_id: "1668",
          num_seasons: 1,
          episodes_per_season: 1,
          metadata_refreshed_at: DateTime.add(DateTime.utc_now(), -16, :minute)
        )
      )

      stub_tv_metadata(%{1 => [1]})

      candidate =
        candidate_with(%EpisodeIdentity{tmdb_id: 1668, season_number: 2, episode_number: 1})

      assert_raise RuntimeError,
                   ~r/TV Show Episode S02E01 for TMDB TV Show 1668 is still missing/,
                   fn ->
                     MatchContent.apply(candidate)
                   end
    end

    test "does not fetch again for a missing TV Show Episode under the 15-minute max_age" do
      generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 1))

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn _conn ->
        flunk("a recently refreshed TV Show must not make a TMDB request")
      end)

      candidate =
        candidate_with(%EpisodeIdentity{tmdb_id: 1668, season_number: 2, episode_number: 1})

      assert_raise RuntimeError,
                   ~r/TV Show Episode S02E01 for TMDB TV Show 1668 is still missing/,
                   fn ->
                     MatchContent.apply(candidate)
                   end
    end

    test "passes through with matched_id: nil when no TV strategy matches" do
      candidate = candidate_with(%EpisodeIdentity{season_number: 1, episode_number: 3})

      assert %Candidate{match_result: %MatchResult{result: :not_matched, matched_id: nil}} =
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

  defp stub_tv_metadata(episodes_by_season, before_response \\ fn _conn -> :ok end) do
    stub_tmdb(fn conn, path ->
      before_response.(conn)

      case Regex.run(~r{/tv/1668/season/(\d+)$}, path) do
        [_, season] ->
          %{
            "season_number" => String.to_integer(season),
            "episodes" =>
              Enum.map(Map.fetch!(episodes_by_season, String.to_integer(season)), fn number ->
                %{"episode_number" => number, "name" => "Episode #{number}"}
              end)
          }

        nil ->
          tmdb_fixture("tv_details_1668")
          |> Map.put(
            "seasons",
            Enum.map(episodes_by_season, fn {season, episodes} ->
              %{"season_number" => season, "episode_count" => length(episodes)}
            end)
          )
      end
    end)
  end

  # Keep the HTTP request blocked until every file has joined the same fetch.
  defp await_metadata_callers(count, attempts \\ 100)

  defp await_metadata_callers(_count, 0), do: flunk("files did not join the metadata fetch")

  defp await_metadata_callers(count, attempts) do
    callers =
      WatchClub.Contents.MetadataFetcher
      |> :sys.get_state()
      |> Map.values()
      |> Enum.flat_map(& &1.callers)

    if length(callers) == count do
      :ok
    else
      Process.sleep(10)
      await_metadata_callers(count, attempts - 1)
    end
  end
end
