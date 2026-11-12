defmodule WatchClub.MediaSources.Import.Ingestor.MatchContentTest do
  use WatchClub.DataCase, async: false

  alias WatchClub.Contents.{Content, ContentIdentity, TvShowEpisodeLocalization}
  alias WatchClub.MediaCatalog
  alias WatchClub.MediaSources.Import.Candidate

  alias WatchClub.MediaSources.Import.Candidate.{
    EpisodeIdentity,
    MatchResult,
    MovieIdentity,
    SportsEventIdentity
  }

  alias WatchClub.MediaSources.Import.Candidate.EpisodeIdentity.Episode

  alias WatchClub.MediaSources.Import.Ingestor.MatchContent

  describe "apply!/1" do
    test "keeps the Manual Match of the file's Media without HTTP requests" do
      manual_match = generate(movie())
      media = generate(video_media(generate(movie()), path: "/library/file.mkv"))

      MediaCatalog.match_media!(media, ContentIdentity.from_content(manual_match),
        actor: generate(administrator())
      )

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn _conn ->
        flunk("a Manual Match must not make a TMDB request")
      end)

      candidate = candidate_with(%MovieIdentity{tmdb_id: 11})

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 reason: :manual_match,
                 parts: [%{movie_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

      assert matched_id == manual_match.id
    end

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

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{movie_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

      assert matched_id == movie.id
    end

    test "creates and matches a movie that does not exist" do
      stub_tmdb(fn _conn, path ->
        tmdb_id = path |> Path.basename() |> String.to_integer()
        Map.put(tmdb_fixture("movie_details_11"), "id", tmdb_id)
      end)

      candidate = candidate_with(%MovieIdentity{tmdb_id: 11})

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{movie_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

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
        assert %Candidate{
                 match_result: %MatchResult{
                   result: :matched,
                   parts: [%{movie_id: matched_id, number: 1}]
                 }
               } =
                 MatchContent.apply!(candidate)

        assert matched_id == movie.id
      end

      assert_receive :fetched_metadata
      assert_receive :fetched_metadata
      refute_receive :fetched_metadata, 0
    end

    test "matches files with different IMDB ids to their own Movies, asking TMDB once per id" do
      first = generate(movie(external_id: "11"))
      second = generate(movie(external_id: "12"))
      ref = :telemetry_test.attach_event_handlers(self(), [[:req, :request, :adapter, :stop]])
      on_exit(fn -> :telemetry.detach(ref) end)

      stub_tmdb(fn _conn, path ->
        %{
          "movie_results" => [
            %{"id" => if(String.ends_with?(path, "tt0000011"), do: 11, else: 12)}
          ]
        }
      end)

      for {imdb_id, movie} <- [{"tt0000011", first}, {"tt0000012", second}, {"tt0000011", first}] do
        assert %Candidate{
                 match_result: %MatchResult{
                   result: :matched,
                   parts: [%{movie_id: matched_id, number: 1}]
                 }
               } =
                 MatchContent.apply!(candidate_with(%MovieIdentity{imdb_id: imdb_id}))

        assert matched_id == movie.id
      end

      # The third file is answered from the cache
      for _ <- 1..2 do
        assert_received {[:req, :request, :adapter, :stop], ^ref, %{duration: _},
                         %{url: %URI{path: "/3/find/:external_id"}, status: 200}}
      end

      refute_received {[:req, :request, :adapter, :stop], ^ref, _, _}
    end

    test "matches by IMDB id" do
      movie = generate(movie(external_id: "11"))

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/find/tt0076759")
        %{"movie_results" => [%{"id" => 11}]}
      end)

      candidate = candidate_with(%MovieIdentity{imdb_id: "tt0076759"})

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{movie_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

      assert matched_id == movie.id
    end

    test "matches by title and year" do
      movie = generate(movie(external_id: "11"))

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/search/movie")
        %{"results" => [%{"id" => 11}]}
      end)

      candidate = candidate_with(%MovieIdentity{title: "Star Wars", year: 1977})

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{movie_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

      assert matched_id == movie.id
    end

    test "matches by title alone when the year is unknown" do
      movie = generate(movie(external_id: "976378"))

      stub_tmdb(fn conn, _path ->
        assert String.ends_with?(conn.request_path, "/search/movie")

        refute Map.has_key?(
                 Plug.Conn.fetch_query_params(conn).query_params,
                 "primary_release_year"
               )

        %{"results" => [%{"id" => 976_378}]}
      end)

      candidate = candidate_with(%MovieIdentity{title: "UFC Fight Night - Holm vs Vieira"})

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{movie_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

      assert matched_id == movie.id
    end

    test "passes through unmatched when no movie strategy matches" do
      candidate = candidate_with(%MovieIdentity{})

      assert %Candidate{
               match_result: %MatchResult{
                 result: :unmatched,
                 reason: :content_not_found,
                 parts: []
               }
             } =
               MatchContent.apply!(candidate)
    end

    test "passes through unmatched when TMDB title search returns no results" do
      stub_tmdb(fn _conn, _path -> %{"results" => []} end)

      candidate = candidate_with(%MovieIdentity{title: "Unknown Film", year: 1999})

      assert %Candidate{match_result: %MatchResult{result: :unmatched, parts: []}} =
               MatchContent.apply!(candidate)
    end

    test "raises when TMDB returns an HTTP error, so that the Oban job retries" do
      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn conn ->
        Plug.Conn.send_resp(conn, 503, "")
      end)

      candidate = candidate_with(%MovieIdentity{imdb_id: "tt0076759"})

      assert_raise MatchError, fn -> MatchContent.apply!(candidate) end
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
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes: [%Episode{season_number: 1, episode_number: 3}]
        })

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{tv_show_episode_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

      assert matched_id == episode.id
    end

    test "creates and matches an episode whose show does not exist" do
      stub_tv_metadata(%{1 => [3]})

      candidate =
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes: [%Episode{season_number: 1, episode_number: 3}]
        })

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{tv_show_episode_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

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
        candidate_with(%EpisodeIdentity{
          tvdb_id: 79_168,
          episodes: [%Episode{season_number: 1, episode_number: 3}]
        })

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{tv_show_episode_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

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
          episodes: [%Episode{season_number: 1, episode_number: 3}]
        })

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{tv_show_episode_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

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
        candidate_with(%EpisodeIdentity{
          title: "Friends",
          episodes: [%Episode{season_number: 1, episode_number: 3}]
        })

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{tv_show_episode_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

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
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes: [%Episode{season_number: 1, episode_number: 2}]
        })

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{tv_show_episode_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

      assert %{tv_show_id: show_id, season_number: 1, episode_number: 2} =
               Ash.get!(WatchClub.Contents.TvShowEpisode, matched_id)

      assert show_id == show.id
    end

    test "the first file of a new season refreshes the TV Show and later files reuse it" do
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
        send(parent, {:fetched_metadata, conn.request_path})
      end)

      for number <- 1..3 do
        assert %Candidate{
                 match_result: %MatchResult{result: :matched, parts: [%{tv_show_episode_id: id}]}
               } =
                 MatchContent.apply!(
                   candidate_with(%EpisodeIdentity{
                     tmdb_id: 1668,
                     episodes: [%Episode{season_number: 2, episode_number: number}]
                   })
                 )

        assert is_binary(id)
      end

      # Only the first file fetches: two Locales, each with the TV Show's details and two seasons
      for _ <- 1..6, do: assert_receive({:fetched_metadata, _})
      refute_receive {:fetched_metadata, _}, 0
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

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{tv_show_episode_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(
                 candidate_with(%EpisodeIdentity{
                   tmdb_id: 1668,
                   episodes: [%Episode{season_number: 1, episode_number: 1}]
                 })
               )

      assert matched_id == episode.id
      assert Ash.get!(Content, show.id).metadata_refreshed_at == show.metadata_refreshed_at
    end

    test "is unmatched when TMDB still does not list the file's TV Show Episode" do
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
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes: [%Episode{season_number: 2, episode_number: 1}]
        })

      assert %Candidate{
               match_result: %MatchResult{
                 result: :unmatched,
                 reason: :episode_not_listed,
                 parts: []
               }
             } =
               MatchContent.apply!(candidate)
    end

    test "does not fetch again for a missing TV Show Episode under the 15-minute max_age" do
      generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 1))

      Req.Test.stub(WatchClub.Integrations.Tmdb.Client, fn _conn ->
        flunk("a recently refreshed TV Show must not make a TMDB request")
      end)

      candidate =
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes: [%Episode{season_number: 2, episode_number: 1}]
        })

      assert %Candidate{match_result: %MatchResult{result: :unmatched}} =
               MatchContent.apply!(candidate)
    end

    test "passes through unmatched when no TV strategy matches" do
      candidate =
        candidate_with(%EpisodeIdentity{
          episodes: [%Episode{season_number: 1, episode_number: 3}]
        })

      assert %Candidate{match_result: %MatchResult{result: :unmatched, parts: []}} =
               MatchContent.apply!(candidate)
    end

    test "matches an episode numbered differently by its title, as the Part its title names" do
      show = generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 2))
      [fun_run, _dunder_mifflin_infinity] = title(show, ["Fun Run", "Dunder Mifflin Infinity"])

      candidate =
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes: [
            %Episode{
              season_number: 1,
              episode_number: 2,
              title: "Fun Run (2)",
              air_date: fun_run.air_date
            }
          ]
        })

      assert %Candidate{match_result: %MatchResult{result: :matched, parts: [part]}} =
               MatchContent.apply!(candidate)

      assert part == %{tv_show_episode_id: fun_run.id, number: 2}
    end

    test "matches an episode without an air date by its title in the same season" do
      show = generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 2))
      [fun_run, _dunder_mifflin_infinity] = title(show, ["Fun Run", "Dunder Mifflin Infinity"])

      candidate =
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes: [%Episode{season_number: 1, episode_number: 2, title: "Fun Run (2)"}]
        })

      assert %Candidate{match_result: %MatchResult{result: :matched, parts: [part]}} =
               MatchContent.apply!(candidate)

      assert part == %{tv_show_episode_id: fun_run.id, number: 2}
    end

    test "doesn't match an episode without an air date by its title in another season" do
      show = generate(tv_show(external_id: "1668", num_seasons: 2, episodes_per_season: 1))
      [_fun_run, season_2_premiere] = title(show, ["Fun Run", "Weight Loss"])

      candidate =
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes: [%Episode{season_number: 2, episode_number: 1, title: "Fun Run (2)"}]
        })

      assert %Candidate{match_result: %MatchResult{result: :matched, parts: [part]}} =
               MatchContent.apply!(candidate)

      assert part == %{tv_show_episode_id: season_2_premiere.id, number: 1}
    end

    test "matches an episode with the TV Show Episode's number and title to its Part 1, even with a part marker" do
      show = generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 2))

      [_take_a_break, morning_after] =
        title(show, ["The One Where Ross and Rachel Take a Break", "The One the Morning After"])

      candidate =
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes: [
            %Episode{
              season_number: 1,
              episode_number: 2,
              title: "The One the Morning After (2)",
              air_date: morning_after.air_date
            }
          ]
        })

      assert %Candidate{match_result: %MatchResult{result: :matched, parts: [part]}} =
               MatchContent.apply!(candidate)

      assert part == %{tv_show_episode_id: morning_after.id, number: 1}
    end

    test "matches a file holding every half of a TV Show Episode to all its Parts" do
      show = generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 2))
      [fun_run, _dunder_mifflin_infinity] = title(show, ["Fun Run", "Dunder Mifflin Infinity"])

      candidate =
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes:
            for {number, title} <- [{1, "Fun Run (1)"}, {2, "Fun Run (2)"}] do
              %Episode{
                season_number: 1,
                episode_number: number,
                title: title,
                air_date: fun_run.air_date
              }
            end
        })

      assert %Candidate{match_result: %MatchResult{result: :matched, parts: parts}} =
               MatchContent.apply!(candidate)

      assert parts == [
               %{tv_show_episode_id: fun_run.id, number: 1},
               %{tv_show_episode_id: fun_run.id, number: 2}
             ]
    end

    test "matches a file holding two TV Show Episodes to a Part of each" do
      show = generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 2))
      [first, second] = title(show, ["The Pilot (1)", "The Pilot (2)"])

      candidate =
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes:
            for episode <- [first, second] do
              %Episode{
                season_number: 1,
                episode_number: episode.episode_number,
                title: "The Pilot (#{episode.episode_number})",
                air_date: episode.air_date
              }
            end
        })

      assert %Candidate{match_result: %MatchResult{result: :matched, parts: parts}} =
               MatchContent.apply!(candidate)

      assert parts == [
               %{tv_show_episode_id: first.id, number: 1},
               %{tv_show_episode_id: second.id, number: 1}
             ]
    end

    test "matches an episode whose number and title match none by its TVDB id" do
      show = generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 2))
      [_gossip, meeting] = title(show, ["Gossip", "The Meeting"])

      stub_tmdb(fn conn, path ->
        assert path == "/3/find/1602631"
        assert Plug.Conn.fetch_query_params(conn).query_params["external_source"] == "tvdb_id"

        %{
          "tv_episode_results" => [
            %{"show_id" => 1668, "season_number" => 1, "episode_number" => 2}
          ]
        }
      end)

      candidate =
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes: [
            %Episode{season_number: 1, episode_number: 3, title: "Meeting", tvdb_id: 1_602_631}
          ]
        })

      assert %Candidate{match_result: %MatchResult{result: :matched, parts: [part]}} =
               MatchContent.apply!(candidate)

      assert part == %{tv_show_episode_id: meeting.id, number: 1}
    end

    test "is unmatched when TMDB doesn't list one of the TV Show Episodes a file holds" do
      generate(tv_show(external_id: "1668", num_seasons: 1, episodes_per_season: 1))

      candidate =
        candidate_with(%EpisodeIdentity{
          tmdb_id: 1668,
          episodes: [
            %Episode{season_number: 1, episode_number: 1},
            %Episode{season_number: 1, episode_number: 2}
          ]
        })

      assert %Candidate{match_result: %MatchResult{result: :unmatched, parts: []}} =
               MatchContent.apply!(candidate)
    end

    test "matches a Sports Event refreshed under 15 minutes ago by its Sportarr ID" do
      event = generate(sports_event(external_id: "ev-028133"))

      Req.Test.stub(WatchClub.Integrations.SportarrHub, fn _conn ->
        flunk("a recently refreshed Sports Event must not make a sportarr.net request")
      end)

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{sports_event_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate_with(%SportsEventIdentity{sportarr_id: "ev-028133"}))

      assert matched_id == event.id
    end

    test "matches a Sports Event by title, dropping the words its title doesn't have" do
      event = generate(sports_event(external_id: "ev-570615"))

      Req.Test.stub(WatchClub.Integrations.SportarrHub, fn conn ->
        events =
          case URI.decode(conn.request_path) do
            "/api/v2/json/search/event/UFC%328" ->
              [
                %{"idEvent" => "ev-1", "strEvent" => "UFC 328", "dateEvent" => "2001-05-04"},
                %{"idEvent" => "ev-570615", "strEvent" => "UFC 328", "dateEvent" => "2026-05-09"}
              ]

            "/api/v2/json/search/event/UFC%328%Prelims" ->
              nil
          end

        Req.Test.json(conn, %{"data" => %{"search" => events}})
      end)

      candidate = candidate_with(%SportsEventIdentity{title: "UFC 328 - Prelims", year: 2026})

      assert %Candidate{
               match_result: %MatchResult{
                 result: :matched,
                 parts: [%{sports_event_id: matched_id, number: 1}]
               }
             } =
               MatchContent.apply!(candidate)

      assert matched_id == event.id
    end

    test "doesn't match a Sports Event when the title matches several events of its year" do
      Req.Test.stub(WatchClub.Integrations.SportarrHub, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{
            "search" => [
              %{
                "idEvent" => "ev-1",
                "strEvent" => "70th Anniversary - Race",
                "dateEvent" => "2020-08-09"
              },
              %{
                "idEvent" => "ev-2",
                "strEvent" => "70th Anniversary - Qualifying",
                "dateEvent" => "2020-08-08"
              }
            ]
          }
        })
      end)

      assert %Candidate{match_result: %MatchResult{result: :unmatched}} =
               MatchContent.apply!(
                 candidate_with(%SportsEventIdentity{title: "Formula 1", year: 2020})
               )
    end

    test "doesn't match a Sports Event by a single word of its title" do
      Req.Test.stub(WatchClub.Integrations.SportarrHub, fn conn ->
        assert URI.decode(conn.request_path) == "/api/v2/json/search/event/UFC%Prelims"
        Req.Test.json(conn, %{"data" => %{"search" => nil}})
      end)

      assert %Candidate{match_result: %MatchResult{result: :unmatched}} =
               MatchContent.apply!(candidate_with(%SportsEventIdentity{title: "UFC Prelims"}))
    end
  end

  defp candidate_with(identity) do
    %Candidate{
      media_source_id: default_media_source_id(),
      path: "/library/file.mkv",
      identity: identity
    }
  end

  # Gives the TV Show's episodes these English titles, in order, and returns them
  defp title(show, titles) do
    show.tv_show.episodes
    |> Enum.sort_by(&{&1.season_number, &1.episode_number})
    |> Enum.zip_with(titles, fn episode, title ->
      Ash.Seed.seed!(TvShowEpisodeLocalization, %{
        tv_show_episode_id: episode.id,
        iso_639_1: "en",
        iso_3166_1: "US",
        title: title
      })

      episode
    end)
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
end
