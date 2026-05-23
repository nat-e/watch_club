defmodule WatchClub.Media.ImportPipeline.ExtractIdentity.ExternalIdExtractorTest do
  @moduledoc """
  Port of Jellyfin's `ProviderIdParserTests.cs` at
  `tests/Jellyfin.Common.Tests/Providers/ProviderIdParserTests.cs`.

  Each Jellyfin `[InlineData]` line is its own test so failures are
  pinpointable. The cases we explicitly don't replicate are marked with
  `@tag :jellyfin_divergence` and an explanation.
  """

  use ExUnit.Case, async: true

  alias WatchClub.Media.ImportPipeline.ExtractIdentity.ExternalIdExtractor

  describe "find_imdb/1 — valid (Jellyfin: FindImdbId_Valid_Success)" do
    test ~s{"tt1234567"} do
      assert ExternalIdExtractor.find_imdb("tt1234567") == "tt1234567"
    end

    test ~s{"tt12345678"} do
      assert ExternalIdExtractor.find_imdb("tt12345678") == "tt12345678"
    end

    test ~s{"https://www.imdb.com/title/tt1234567"} do
      assert ExternalIdExtractor.find_imdb("https://www.imdb.com/title/tt1234567") == "tt1234567"
    end

    test ~s{"https://www.imdb.com/title/tt12345678"} do
      assert ExternalIdExtractor.find_imdb("https://www.imdb.com/title/tt12345678") == "tt12345678"
    end

    test ~s{multiline (literal \\n) with 7-digit URL} do
      assert ExternalIdExtractor.find_imdb("multiline\\nhttps://www.imdb.com/title/tt1234567") ==
               "tt1234567"
    end

    test ~s{multiline (literal \\n) with 8-digit URL} do
      assert ExternalIdExtractor.find_imdb("multiline\\nhttps://www.imdb.com/title/tt12345678") ==
               "tt12345678"
    end

    test ~s{"tt1234567tt7654321" — first match wins} do
      assert ExternalIdExtractor.find_imdb("tt1234567tt7654321") == "tt1234567"
    end

    test ~s{"tt12345678tt7654321"} do
      assert ExternalIdExtractor.find_imdb("tt12345678tt7654321") == "tt12345678"
    end

    test ~s{"tt123456789" — captures max 8 digits} do
      assert ExternalIdExtractor.find_imdb("tt123456789") == "tt12345678"
    end
  end

  describe "find_imdb/1 — invalid (Jellyfin: FindImdbId_Invalid_Success)" do
    test ~s{"tt123456" — only 6 digits} do
      assert ExternalIdExtractor.find_imdb("tt123456") == nil
    end

    test ~s{"https://www.imdb.com/title/tt123456"} do
      assert ExternalIdExtractor.find_imdb("https://www.imdb.com/title/tt123456") == nil
    end

    test ~s{"Jellyfin"} do
      assert ExternalIdExtractor.find_imdb("Jellyfin") == nil
    end
  end

  describe "find_tmdb/1 — movie URLs valid (Jellyfin: FindTmdbMovieId_Valid_Success)" do
    test ~s{"https://www.themoviedb.org/movie/30287-fallo"} do
      assert ExternalIdExtractor.find_tmdb("https://www.themoviedb.org/movie/30287-fallo") ==
               "30287"
    end

    test ~s{"themoviedb.org/movie/30287"} do
      assert ExternalIdExtractor.find_tmdb("themoviedb.org/movie/30287") == "30287"
    end
  end

  describe "find_tmdb/1 — movie URLs invalid (Jellyfin: FindTmdbMovieId_Invalid_Success)" do
    test ~s{"https://www.themoviedb.org/movie/fallo-30287" — slug-first} do
      assert ExternalIdExtractor.find_tmdb("https://www.themoviedb.org/movie/fallo-30287") == nil
    end
  end

  describe "find_tmdb/1 — series URLs valid (Jellyfin: FindTmdbSeriesId_Valid_Success)" do
    test ~s{"https://www.themoviedb.org/tv/1668-friends"} do
      assert ExternalIdExtractor.find_tmdb("https://www.themoviedb.org/tv/1668-friends") == "1668"
    end

    test ~s{"themoviedb.org/tv/1668"} do
      assert ExternalIdExtractor.find_tmdb("themoviedb.org/tv/1668") == "1668"
    end
  end

  describe "find_tmdb/1 — series URLs invalid (Jellyfin: FindTmdbSeriesId_Invalid_Success)" do
    test ~s{"https://www.themoviedb.org/tv/friends-1668" — slug-first} do
      assert ExternalIdExtractor.find_tmdb("https://www.themoviedb.org/tv/friends-1668") == nil
    end
  end

  describe "find_tvdb/1 — valid (Jellyfin: FindTvdbId_Valid_Success)" do
    test ~s{"https://www.thetvdb.com/?tab=series&id=121361"} do
      assert ExternalIdExtractor.find_tvdb("https://www.thetvdb.com/?tab=series&id=121361") ==
               "121361"
    end

    test ~s{"thetvdb.com/?tab=series&id=121361"} do
      assert ExternalIdExtractor.find_tvdb("thetvdb.com/?tab=series&id=121361") == "121361"
    end
  end

  describe "find_tvdb/1 — invalid (Jellyfin: FindTvdbId_Invalid_Success)" do
    test ~s{"thetvdb.com/?tab=series&id=Jellyfin121361" — non-numeric id} do
      assert ExternalIdExtractor.find_tvdb("thetvdb.com/?tab=series&id=Jellyfin121361") == nil
    end

    test ~s{"https://www.themoviedb.org/tv/1668-friends" — wrong host} do
      assert ExternalIdExtractor.find_tvdb("https://www.themoviedb.org/tv/1668-friends") == nil
    end
  end

  describe "from_text/1 — bracket attributes (Jellyfin: PathExtensions.GetAttributeValue)" do
    test "[imdbid-tt1375666]" do
      assert ExternalIdExtractor.from_text("Inception (2010) [imdbid-tt1375666].mkv").imdb ==
               "tt1375666"
    end

    test "{tmdb-27205}" do
      assert ExternalIdExtractor.from_text("Inception {tmdb-27205}.mkv").tmdb == 27205
    end

    test "(tvdbid=121361)" do
      assert ExternalIdExtractor.from_text("Show (tvdbid=121361)/file.mkv").tvdb == 121_361
    end

    test "bracket attribute wins over no other source" do
      result = ExternalIdExtractor.from_text("File [imdb-tt1375666] [tmdb-27205].mkv")
      assert result.imdb == "tt1375666"
      assert result.tmdb == 27205
    end
  end

  describe "from_text/1 — uniqueid tag (Jellyfin: BaseNfoParser.ParseProviderLinks)" do
    test ~s{<uniqueid type="tmdb">141052</uniqueid>} do
      xml = ~s{<uniqueid type="tmdb">141052</uniqueid>}
      assert ExternalIdExtractor.from_text(xml).tmdb == 141_052
    end

    test ~s{<uniqueid type="imdb">tt0974015</uniqueid>} do
      xml = ~s{<uniqueid type="imdb">tt0974015</uniqueid>}
      assert ExternalIdExtractor.from_text(xml).imdb == "tt0974015"
    end

    test ~s{<uniqueid type="tvdb">253573</uniqueid>} do
      xml = ~s{<uniqueid type="tvdb">253573</uniqueid>}
      assert ExternalIdExtractor.from_text(xml).tvdb == 253_573
    end
  end
end
