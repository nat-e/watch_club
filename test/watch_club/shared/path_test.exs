defmodule WatchClub.Shared.PathTest do
  use ExUnit.Case, async: true

  alias WatchClub.Shared.Path, as: Paths

  describe "normalize/1" do
    test "returns nil for nil" do
      assert Paths.normalize(nil) == nil
    end

    test "strips trailing slashes and collapses separators" do
      assert Paths.normalize("/movies/") == "/movies"
      assert Paths.normalize("/movies//Star Wars/") == "/movies/Star Wars"
    end

    test "resolves . and .." do
      assert Paths.normalize("/movies/./a/../b") == "/movies/b"
    end

    test "is idempotent" do
      once = Paths.normalize("/movies/Star Wars (1977)/")
      assert Paths.normalize(once) == once
    end
  end

  describe "remap_prefix/3" do
    test "swaps the root prefix and normalizes" do
      assert Paths.remap_prefix("/movies/Film/f.mkv", "/movies", "/data/movies") ==
               "/data/movies/Film/f.mkv"
    end

    test "tolerates trailing slashes on either root" do
      assert Paths.remap_prefix("/movies/Film/f.mkv", "/movies/", "/data/movies/") ==
               "/data/movies/Film/f.mkv"
    end

    test "only normalizes when the local root is nil (shared mount)" do
      assert Paths.remap_prefix("/movies/Film/f.mkv", "/movies", nil) ==
               "/movies/Film/f.mkv"
    end
  end
end
