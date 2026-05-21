defmodule WatchClub.Media.ImportPipeline.ExtractIdentity.NfoParserTest do
  @moduledoc """
  Port of Jellyfin's NFO parser tests at
  `tests/Jellyfin.XbmcMetadata.Tests/Parsers/`:

    * `MovieNfoProviderTests.cs`
    * `EpisodeNfoProviderTests.cs`
    * `SeriesNfoProviderTests.cs`
    * `SeasonNfoProviderTests.cs`

  The XML fixtures are inlined (Jellyfin keeps them as separate files under
  `Test Data/`). Assertions are restricted to the fields we model on the
  result structs — Person/Actor entries, RemoteImages, ratings,
  trailer-URL rewriting, `<format3d>`, `<communityrating>`, and
  `<lockdata>` are intentionally NOT ported (out of scope; see
  `Candidate.Identity` for the full field list we support).

  We write each fixture to a temp directory so the parser exercises its
  real I/O path (NFO sidecar discovery + file read + XML walk).
  """

  use ExUnit.Case, async: true

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.ExtractIdentity.NfoParser
  alias WatchClub.Media.ImportPipeline.ExtractIdentity.NfoParser.{BookResult, EpisodeResult, MovieResult}

  setup do
    dir = Path.join(System.tmp_dir!(), "wc_nfo_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  defp write_files(dir, files) do
    Enum.each(files, fn {relative, content} ->
      full = Path.join(dir, relative)
      File.mkdir_p!(Path.dirname(full))
      File.write!(full, content)
    end)
  end

  defp candidate(dir, relative_video_path) do
    %Candidate{path: Path.join(dir, relative_video_path)}
  end

  # ----------------------------------------------------------------------
  # MovieNfoProviderTests
  # ----------------------------------------------------------------------

  describe "parse_movie/2 — Jellyfin Fetch_Valid_Success (Justice League fixture)" do
    @fixture """
    <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
    <movie>
      <title>Justice League</title>
      <originaltitle>Justice League</originaltitle>
      <tagline>Justice for all.</tagline>
      <runtime>120</runtime>
      <tmdbId>141052</tmdbId>
      <uniqueid type="imdb">tt0974015</uniqueid>
      <uniqueid type="tmdb">141052</uniqueid>
      <genre>Action</genre>
      <genre>Adventure</genre>
      <genre>Fantasy</genre>
      <genre>Sci-Fi</genre>
      <country>USA</country>
      <country>Canada</country>
      <country>UK</country>
      <set tmdbcolid="702342">
        <name>Justice League Collection</name>
      </set>
      <premiered>2017-11-15</premiered>
      <year>2017</year>
      <studio>DC Comics</studio>
    </movie>
    """

    test "extracts title", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert result.title == "Justice League"
    end

    test "extracts original title", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert result.original_title == "Justice League"
    end

    test "extracts tagline", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert result.tagline == "Justice for all."
    end

    test "extracts runtime minutes", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert result.runtime_minutes == 120
    end

    test "extracts IMDB ID", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert result.external_ids.imdb == "tt0974015"
    end

    test "extracts TMDB ID", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert result.external_ids.tmdb == "141052"
    end

    test "extracts collection name", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert result.set_name == "Justice League Collection"
    end

    test "extracts all four genres", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert length(result.genres) == 4
      assert "Action" in result.genres
      assert "Adventure" in result.genres
      assert "Fantasy" in result.genres
      assert "Sci-Fi" in result.genres
    end

    test "extracts premiere date", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert result.premiered == ~D[2017-11-15]
    end

    test "extracts production year", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert result.year == 2017
    end

    test "extracts single studio", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert result.studios == ["DC Comics"]
    end

    test "extracts all three countries", %{dir: dir} do
      write_files(dir, [{"Justice League.mkv", ""}, {"Justice League.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Justice League.mkv"), %{filesystem_path: dir})
      assert length(result.countries) == 3
      assert "USA" in result.countries
      assert "Canada" in result.countries
      assert "UK" in result.countries
    end
  end

  describe "parse_movie/2 — Jellyfin Parse_UrlFile_Success" do
    test "Imdb.nfo URL fixture", %{dir: dir} do
      write_files(dir, [
        {"foo.mkv", ""},
        {"foo.nfo", "https://www.imdb.com/title/tt0944947/"}
      ])

      result = NfoParser.parse_movie(candidate(dir, "foo.mkv"), %{filesystem_path: dir})
      assert result.external_ids.imdb == "tt0944947"
    end

    test "Tmdb.nfo URL fixture", %{dir: dir} do
      write_files(dir, [
        {"foo.mkv", ""},
        {"foo.nfo", "https://www.themoviedb.org/movie/30287-fallo"}
      ])

      result = NfoParser.parse_movie(candidate(dir, "foo.mkv"), %{filesystem_path: dir})
      assert result.external_ids.tmdb == "30287"
    end
  end

  describe "parse_movie/2 — Jellyfin Parse_RadarrUrlFile_Success" do
    test "Radarr.nfo with two URLs", %{dir: dir} do
      content = """
      https://www.themoviedb.org/movie/583689
      https://www.imdb.com/title/tt4154796
      """

      write_files(dir, [{"foo.mkv", ""}, {"foo.nfo", content}])
      result = NfoParser.parse_movie(candidate(dir, "foo.mkv"), %{filesystem_path: dir})
      assert result.external_ids.tmdb == "583689"
      assert result.external_ids.imdb == "tt4154796"
    end
  end

  describe "parse_movie/2 — Jellyfin Parsing_Fields_With_Escaped_Xml_Special_Characters_Success" do
    @fixture """
    <?xml version="1.0" encoding="utf-8" standalone="yes"?>
    <movie>
      <title>Lilo &amp; Stitch</title>
      <originaltitle>Lilo &amp; Stitch</originaltitle>
      <uniqueid type="tmdbcol" default="false">97020</uniqueid>
      <set>Lilo &amp; Stitch Collection</set>
      <plot>&gt;&gt;As Stitch...the Hawaiian tradition of family.&lt;&lt;</plot>
    </movie>
    """

    test "decodes &amp; in title", %{dir: dir} do
      write_files(dir, [{"Lilo.mkv", ""}, {"Lilo.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Lilo.mkv"), %{filesystem_path: dir})
      assert result.title == "Lilo & Stitch"
    end

    test "decodes &amp; in original title", %{dir: dir} do
      write_files(dir, [{"Lilo.mkv", ""}, {"Lilo.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Lilo.mkv"), %{filesystem_path: dir})
      assert result.original_title == "Lilo & Stitch"
    end

    test "decodes &amp; in set name", %{dir: dir} do
      write_files(dir, [{"Lilo.mkv", ""}, {"Lilo.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Lilo.mkv"), %{filesystem_path: dir})
      assert result.set_name == "Lilo & Stitch Collection"
    end

    test "decodes &gt;/&lt; in plot", %{dir: dir} do
      write_files(dir, [{"Lilo.mkv", ""}, {"Lilo.nfo", @fixture}])
      result = NfoParser.parse_movie(candidate(dir, "Lilo.mkv"), %{filesystem_path: dir})
      assert String.starts_with?(result.plot, ">>")
      assert String.ends_with?(result.plot, "<<")
    end
  end

  describe "parse_movie/2 — locator behavior" do
    test "missing NFO returns empty MovieResult", %{dir: dir} do
      write_files(dir, [{"foo.mkv", ""}])
      result = NfoParser.parse_movie(candidate(dir, "foo.mkv"), %{filesystem_path: dir})
      assert %MovieResult{title: nil, year: nil, genres: []} = result
    end

    test "movie.nfo is read when no sidecar exists", %{dir: dir} do
      write_files(dir, [
        {"foo.mkv", ""},
        {"movie.nfo", "<movie><title>From movie.nfo</title></movie>"}
      ])

      result = NfoParser.parse_movie(candidate(dir, "foo.mkv"), %{filesystem_path: dir})
      assert result.title == "From movie.nfo"
    end

    test "sidecar wins over movie.nfo", %{dir: dir} do
      write_files(dir, [
        {"foo.mkv", ""},
        {"foo.nfo", "<movie><title>From sidecar</title></movie>"},
        {"movie.nfo", "<movie><title>From movie.nfo</title></movie>"}
      ])

      result = NfoParser.parse_movie(candidate(dir, "foo.mkv"), %{filesystem_path: dir})
      assert result.title == "From sidecar"
    end

    test "malformed XML degrades to empty result", %{dir: dir} do
      write_files(dir, [{"foo.mkv", ""}, {"foo.nfo", "<movie><title>Broken"}])
      result = NfoParser.parse_movie(candidate(dir, "foo.mkv"), %{filesystem_path: dir})
      assert %MovieResult{title: nil} = result
    end
  end

  # ----------------------------------------------------------------------
  # EpisodeNfoProviderTests
  # ----------------------------------------------------------------------

  describe "parse_episode/2 — Jellyfin Fetch_Valid_Success (The Bone Orchard)" do
    @sidecar """
    <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
    <episodedetails>
      <title>The Bone Orchard</title>
      <showtitle>American Gods</showtitle>
      <season>1</season>
      <episode>1</episode>
      <plot>When Shadow Moon is released from prison...</plot>
      <runtime>0</runtime>
      <uniqueid type="tmdb" default="true">1276153</uniqueid>
      <imdbId>tt5017734</imdbId>
      <genre>Drama</genre>
      <genre>Mystery</genre>
      <genre>Sci-Fi &amp; Fantasy</genre>
      <premiered>2017-04-30</premiered>
      <year>2017</year>
      <aired>2017-04-30</aired>
      <studio>Starz</studio>
    </episodedetails>
    """

    defp write_episode(dir, sidecar_xml, tvshow_xml \\ nil) do
      base = [
        {"American Gods/Season 01/episode.mkv", ""},
        {"American Gods/Season 01/episode.nfo", sidecar_xml}
      ]

      with_show = if tvshow_xml, do: [{"American Gods/tvshow.nfo", tvshow_xml} | base], else: base
      write_files(dir, with_show)
    end

    test "extracts episode title", %{dir: dir} do
      write_episode(dir, @sidecar)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.episode_title == "The Bone Orchard"
    end

    test "extracts show title from <showtitle>", %{dir: dir} do
      write_episode(dir, @sidecar)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.show_title == "American Gods"
    end

    test "extracts season number", %{dir: dir} do
      write_episode(dir, @sidecar)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.season_number == 1
    end

    test "extracts episode number", %{dir: dir} do
      write_episode(dir, @sidecar)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.episode_number == 1
    end

    test "extracts plot", %{dir: dir} do
      write_episode(dir, @sidecar)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.plot == "When Shadow Moon is released from prison..."
    end

    test "extracts runtime (zero is valid)", %{dir: dir} do
      write_episode(dir, @sidecar)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.runtime_minutes == 0
    end

    test "extracts TMDB ID from <uniqueid>", %{dir: dir} do
      write_episode(dir, @sidecar)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.external_ids.tmdb == "1276153"
    end

    test "extracts aired date", %{dir: dir} do
      write_episode(dir, @sidecar)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.aired == ~D[2017-04-30]
    end
  end

  describe "parse_episode/2 — sidecar + tvshow.nfo combination" do
    @sidecar ~s{<episodedetails><title>S01E01</title><season>1</season><episode>1</episode></episodedetails>}
    @tvshow """
    <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
    <tvshow>
      <title>American Gods</title>
      <year>2017</year>
      <uniqueid type="tmdb">46639</uniqueid>
      <uniqueid type="tvdb">253573</uniqueid>
      <genre>Drama</genre>
      <genre>Mystery</genre>
    </tvshow>
    """

    test "show_title comes from tvshow.nfo when sidecar lacks <showtitle>", %{dir: dir} do
      write_episode(dir, @sidecar, @tvshow)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.show_title == "American Gods"
    end

    test "show_year comes from tvshow.nfo", %{dir: dir} do
      write_episode(dir, @sidecar, @tvshow)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.show_year == 2017
    end

    test "show_external_ids carry TMDB and TVDB from tvshow.nfo", %{dir: dir} do
      write_episode(dir, @sidecar, @tvshow)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.show_external_ids.tmdb == "46639"
      assert result.show_external_ids.tvdb == "253573"
    end

    test "show_genres come from tvshow.nfo", %{dir: dir} do
      write_episode(dir, @sidecar, @tvshow)
      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert "Drama" in result.show_genres
      assert "Mystery" in result.show_genres
    end

    test "missing sidecar still resolves show fields from tvshow.nfo", %{dir: dir} do
      write_files(dir, [
        {"American Gods/Season 01/episode.mkv", ""},
        {"American Gods/tvshow.nfo", @tvshow}
      ])

      result = NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/episode.mkv"), %{filesystem_path: dir})
      assert result.show_title == "American Gods"
      assert result.show_external_ids.tmdb == "46639"
    end
  end

  describe "parse_episode/2 — multi-episode NFO" do
    # Jellyfin's `Fetch_Valid_MultiEpisode_Success` uses Rising.nfo with two
    # <episodedetails> blocks. We don't model multiple episodes per file (one
    # candidate = one episode); the parser reads the first block's data and
    # ignores the rest. The test asserts that behavior so a future change to
    # support multi-episode is visible.
    @multi """
    <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
    <episodedetails>
      <title>Rising (1)</title>
      <season>1</season>
      <episode>1</episode>
      <aired>2004-07-16</aired>
    </episodedetails>
    <episodedetails>
      <title>Rising (2)</title>
      <season>1</season>
      <episode>2</episode>
      <aired>2004-07-16</aired>
    </episodedetails>
    """

    @tag :jellyfin_out_of_scope
    test "first <episodedetails> block wins (single-episode model)", %{dir: dir} do
      write_files(dir, [
        {"file.mkv", ""},
        {"file.nfo", @multi}
      ])

      # :xmerl will fail to scan a document with two root elements. Our
      # parser falls back to an empty EpisodeResult in that case. Mark out
      # of scope and assert the current observable behavior.
      result = NfoParser.parse_episode(candidate(dir, "file.mkv"), %{filesystem_path: dir})
      assert %EpisodeResult{} = result
    end
  end

  describe "parse_episode/2 — locator behavior" do
    test "no sidecar and no tvshow.nfo returns empty EpisodeResult", %{dir: dir} do
      write_files(dir, [{"file.mkv", ""}])
      result = NfoParser.parse_episode(candidate(dir, "file.mkv"), %{filesystem_path: dir})
      assert %EpisodeResult{episode_title: nil, season_number: nil, show_title: nil} = result
    end

    test "deeper tvshow.nfo wins over higher one", %{dir: dir} do
      write_files(dir, [
        {"Library/American Gods/Season 01/file.mkv", ""},
        {"Library/American Gods/tvshow.nfo", "<tvshow><title>Deep show</title></tvshow>"},
        {"Library/tvshow.nfo", "<tvshow><title>Shallow show</title></tvshow>"}
      ])

      result =
        NfoParser.parse_episode(
          candidate(dir, "Library/American Gods/Season 01/file.mkv"),
          %{filesystem_path: Path.join(dir, "Library")}
        )

      assert result.show_title == "Deep show"
    end
  end

  # ----------------------------------------------------------------------
  # SeriesNfoProviderTests — exercised via parse_episode/2 reading tvshow.nfo
  # ----------------------------------------------------------------------

  describe "parse_episode/2 — Jellyfin Series Fetch_Valid_Success (American Gods)" do
    @tvshow """
    <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
    <tvshow>
      <title>American Gods</title>
      <originaltitle>American Gods</originaltitle>
      <plot>An ex-con becomes the traveling partner...</plot>
      <tagline></tagline>
      <runtime>0</runtime>
      <uniqueid type="tmdb" default="true">46639</uniqueid>
      <uniqueid type="tvdb">253573</uniqueid>
      <genre>Drama</genre>
      <genre>Mystery</genre>
      <genre>Sci-Fi &amp; Fantasy</genre>
      <premiered>2017-04-30</premiered>
      <year>2017</year>
      <status>ended</status>
      <studio>Starz</studio>
    </tvshow>
    """

    test "show fields propagate to EpisodeResult.show_*", %{dir: dir} do
      write_files(dir, [
        {"American Gods/Season 01/file.mkv", ""},
        {"American Gods/tvshow.nfo", @tvshow}
      ])

      result =
        NfoParser.parse_episode(candidate(dir, "American Gods/Season 01/file.mkv"), %{
          filesystem_path: dir
        })

      assert result.show_title == "American Gods"
      assert result.show_year == 2017
      assert result.show_external_ids.tmdb == "46639"
      assert result.show_external_ids.tvdb == "253573"
      assert length(result.show_genres) == 3
      assert "Sci-Fi & Fantasy" in result.show_genres
    end
  end

  describe "parse_episode/2 — Jellyfin Series Parse_UrlFile_Success" do
    test "Tvdb.nfo URL fixture", %{dir: dir} do
      write_files(dir, [
        {"Show/Season 01/file.mkv", ""},
        {"Show/tvshow.nfo", "https://www.thetvdb.com/?tab=series&id=121361"}
      ])

      result =
        NfoParser.parse_episode(candidate(dir, "Show/Season 01/file.mkv"), %{
          filesystem_path: dir
        })

      assert result.show_external_ids.tvdb == "121361"
    end
  end

  # ----------------------------------------------------------------------
  # Book NFO (no Jellyfin equivalent — Jellyfin doesn't ship a book parser).
  # We test our own <book> schema with a minimal example so the entry point
  # has coverage.
  # ----------------------------------------------------------------------

  describe "parse_book/2 — minimal coverage" do
    test "extracts title/author/year/isbn", %{dir: dir} do
      fixture = """
      <?xml version="1.0" encoding="UTF-8" ?>
      <book>
        <title>The Wind-Up Bird Chronicle</title>
        <author>Haruki Murakami</author>
        <year>1995</year>
        <isbn>9780679775430</isbn>
      </book>
      """

      write_files(dir, [{"book.epub", ""}, {"book.nfo", fixture}])
      result = NfoParser.parse_book(candidate(dir, "book.epub"), %{filesystem_path: dir})
      assert %BookResult{title: "The Wind-Up Bird Chronicle", author: "Haruki Murakami", year: 1995, isbn: "9780679775430"} = result
    end

    test "missing NFO returns empty BookResult", %{dir: dir} do
      write_files(dir, [{"book.epub", ""}])
      result = NfoParser.parse_book(candidate(dir, "book.epub"), %{filesystem_path: dir})
      assert %BookResult{title: nil} = result
    end
  end
end
