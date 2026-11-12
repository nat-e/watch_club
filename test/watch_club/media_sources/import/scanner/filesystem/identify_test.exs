defmodule WatchClub.MediaSources.Import.Scanner.Filesystem.IdentifyTest do
  use ExUnit.Case, async: true

  alias WatchClub.MediaSources.{Filesystem, Source}
  alias WatchClub.MediaSources.Import.Candidate

  alias WatchClub.MediaSources.Import.Candidate.{
    EpisodeIdentity,
    MovieIdentity,
    SportsEventIdentity
  }

  alias WatchClub.MediaSources.Import.Scanner.Filesystem.Identify

  describe "apply/2 — Sports Events" do
    test "builds a SportsEventIdentity with the title, and the year of the parent directory" do
      candidate =
        Candidate.new(
          "/sports/UFC 294 (2023)/UFC 294 - Makhachev vs Volkanovski 2.mp4",
          :sports_event
        )

      assert %Candidate{
               identity: %SportsEventIdentity{
                 title: "UFC 294 - Makhachev vs Volkanovski 2",
                 year: 2023,
                 sportarr_id: nil
               }
             } = Identify.apply(candidate, source_for(:sports_event, "/sports"))
    end

    test "keeps the words after the event's title, without the release details" do
      candidate =
        Candidate.new("/sports/UFC.328.Prelims.1080p.WEB-DL.H264-GROUP.mp4", :sports_event)

      assert %Candidate{identity: %SportsEventIdentity{title: "UFC 328 Prelims", year: nil}} =
               Identify.apply(candidate, source_for(:sports_event, "/sports"))
    end

    test "extracts the Sportarr ID from Sportarr's file naming" do
      candidate =
        Candidate.new(
          "/sports/UFC/Season 2025/UFC - s2025e002 - UFC 311 - 1080p - sportarr-ev-028133.mkv",
          :sports_event
        )

      assert %Candidate{identity: %SportsEventIdentity{sportarr_id: "ev-028133"}} =
               Identify.apply(candidate, source_for(:sports_event, "/sports"))
    end
  end

  describe "apply/2 — movies" do
    test "builds a MovieIdentity with title and year from the filename" do
      candidate = Candidate.new("/library/Star Wars (1977).mkv", :movie)
      source = source_for(:movie, "/library")

      assert %Candidate{identity: %MovieIdentity{title: "Star Wars", year: 1977}} =
               Identify.apply(candidate, source)
    end

    test "takes the year from the parent directory when the filename has none" do
      candidate = Candidate.new("/library/UFC 100 (2009)/UFC 100 - Lesnar vs Mir 2.mp4", :movie)
      source = source_for(:movie, "/library")

      assert %Candidate{identity: %MovieIdentity{title: "UFC 100 - Lesnar vs Mir 2", year: 2009}} =
               Identify.apply(candidate, source)
    end

    test "prefers the filename's year to the parent directory's" do
      candidate = Candidate.new("/library/300 (2007)/300 (2006).mkv", :movie)
      source = source_for(:movie, "/library")

      assert %Candidate{identity: %MovieIdentity{title: "300", year: 2006}} =
               Identify.apply(candidate, source)
    end

    test "extracts the tmdb id from a bracket in the filename" do
      candidate = Candidate.new("/library/Star Wars (1977) [tmdbid-11].mkv", :movie)
      source = source_for(:movie, "/library")

      assert %Candidate{identity: %MovieIdentity{tmdb_id: 11}} =
               Identify.apply(candidate, source)
    end

    test "extracts the imdb id from a bracket in a parent directory" do
      candidate = Candidate.new("/library/Star Wars [imdbid-tt0076759]/movie.mkv", :movie)
      source = source_for(:movie, "/library")

      assert %Candidate{identity: %MovieIdentity{imdb_id: "tt0076759"}} =
               Identify.apply(candidate, source)
    end
  end

  describe "apply/2 — tv_show_episode" do
    test "builds an EpisodeIdentity with season, episode, and show title from the filename" do
      candidate = Candidate.new("/library/American Gods - S01E03.mkv", :tv_show_episode)
      source = source_for(:tv_show_episode, "/library")

      assert %Candidate{
               identity: %EpisodeIdentity{
                 title: "American Gods",
                 episodes: [%EpisodeIdentity.Episode{season_number: 1, episode_number: 3}]
               }
             } = Identify.apply(candidate, source)
    end

    test "takes the episode's title from the filename" do
      candidate =
        Candidate.new(
          "/library/The Office (US)/Season 04/The Office (US) - S04E02 - Fun Run (2) [WEBDL-1080p]-GRP.mkv",
          :tv_show_episode
        )

      source = source_for(:tv_show_episode, "/library")

      assert %Candidate{
               identity: %EpisodeIdentity{
                 episodes: [
                   %EpisodeIdentity.Episode{
                     season_number: 4,
                     episode_number: 2,
                     title: "Fun Run (2)"
                   }
                 ]
               }
             } = Identify.apply(candidate, source)
    end

    test "builds an episode for each number of a file holding several, each with its title" do
      candidate =
        Candidate.new("/library/Show - S01E01-E02 - Pilot + Second.mkv", :tv_show_episode)

      source = source_for(:tv_show_episode, "/library")

      assert %Candidate{identity: %EpisodeIdentity{episodes: episodes}} =
               Identify.apply(candidate, source)

      assert episodes == [
               %EpisodeIdentity.Episode{season_number: 1, episode_number: 1, title: "Pilot"},
               %EpisodeIdentity.Episode{season_number: 1, episode_number: 2, title: "Second"}
             ]
    end

    test "gives each half of a story in one file the title they share with its part number" do
      candidate =
        Candidate.new("/library/The Office (US) - S04E01-E02 - Fun Run.mkv", :tv_show_episode)

      source = source_for(:tv_show_episode, "/library")

      assert %Candidate{identity: %EpisodeIdentity{episodes: episodes}} =
               Identify.apply(candidate, source)

      assert Enum.map(episodes, &{&1.episode_number, &1.title}) == [
               {1, "Fun Run (1)"},
               {2, "Fun Run (2)"}
             ]
    end

    test "falls back to deriving the show title from the path when the filename lacks one" do
      candidate = Candidate.new("/library/American Gods/Season 01/S01E03.mkv", :tv_show_episode)
      source = source_for(:tv_show_episode, "/library")

      assert %Candidate{identity: %EpisodeIdentity{title: "American Gods"}} =
               Identify.apply(candidate, source)
    end

    test "extracts external ids from the directory, not the basename" do
      candidate =
        Candidate.new(
          "/library/American Gods [tmdbid-46639]/Season 01/S01E03.mkv",
          :tv_show_episode
        )

      source = source_for(:tv_show_episode, "/library")

      assert %Candidate{identity: %EpisodeIdentity{tmdb_id: 46_639}} =
               Identify.apply(candidate, source)
    end
  end

  defp source_for(media_type, root_path) do
    %Source{
      media_type: media_type,
      source_type: :filesystem,
      implementation: %Filesystem{filesystem_path: root_path}
    }
  end
end
