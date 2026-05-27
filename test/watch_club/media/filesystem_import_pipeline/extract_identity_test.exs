defmodule WatchClub.Media.ImportPipeline.ExtractIdentityTest do
  use ExUnit.Case, async: true

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.{EpisodeIdentity, MovieIdentity}
  alias WatchClub.Media.ImportPipeline.ExtractIdentity
  alias WatchClub.Media.{MediaImport, MediaSource}

  describe "apply/2 — movies" do
    test "builds a MovieIdentity with title and year from the filename" do
      candidate = Candidate.new("/library/Star Wars (1977).mkv")
      run = run_for(:movie, "/library")

      assert {:ok, %Candidate{identity: %MovieIdentity{title: "Star Wars", year: 1977}}} =
               ExtractIdentity.apply(candidate, run)
    end

    test "extracts the tmdb id from a bracket in the filename" do
      candidate = Candidate.new("/library/Star Wars (1977) [tmdbid-11].mkv")
      run = run_for(:movie, "/library")

      assert {:ok, %Candidate{identity: %MovieIdentity{tmdb_id: 11}}} =
               ExtractIdentity.apply(candidate, run)
    end

    test "extracts the imdb id from a bracket in a parent directory" do
      candidate = Candidate.new("/library/Star Wars [imdbid-tt0076759]/movie.mkv")
      run = run_for(:movie, "/library")

      assert {:ok, %Candidate{identity: %MovieIdentity{imdb_id: "tt0076759"}}} =
               ExtractIdentity.apply(candidate, run)
    end
  end

  describe "apply/2 — tv_show_episode" do
    test "builds an EpisodeIdentity with season, episode, and show title from the filename" do
      candidate = Candidate.new("/library/American Gods - S01E03.mkv")
      run = run_for(:tv_show_episode, "/library")

      assert {:ok,
              %Candidate{
                identity: %EpisodeIdentity{
                  title: "American Gods",
                  season_number: 1,
                  episode_number: 3
                }
              }} = ExtractIdentity.apply(candidate, run)
    end

    test "falls back to deriving the show title from the path when the filename lacks one" do
      candidate = Candidate.new("/library/American Gods/Season 01/S01E03.mkv")
      run = run_for(:tv_show_episode, "/library")

      assert {:ok, %Candidate{identity: %EpisodeIdentity{title: "American Gods"}}} =
               ExtractIdentity.apply(candidate, run)
    end

    test "extracts external ids from the directory, not the basename" do
      candidate =
        Candidate.new("/library/American Gods [tmdbid-46639]/Season 01/S01E03.mkv")

      run = run_for(:tv_show_episode, "/library")

      assert {:ok, %Candidate{identity: %EpisodeIdentity{tmdb_id: 46639}}} =
               ExtractIdentity.apply(candidate, run)
    end
  end

  defp run_for(media_type, root_path) do
    %MediaImport{
      source_snapshot: %MediaSource{
        media_type: media_type,
        filesystem_path: root_path
      }
    }
  end
end
