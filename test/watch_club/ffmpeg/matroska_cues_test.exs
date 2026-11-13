defmodule WatchClub.Ffmpeg.MatroskaCuesTest do
  use ExUnit.Case, async: true

  alias WatchClub.Ffmpeg.MatroskaCues

  @fixtures Path.join([__DIR__, "../../support/fixtures/matroska"])

  describe "keyframe_times/1" do
    test "lists the keyframes of the first video track, after an audio track" do
      path = Path.join(@fixtures, "audio_then_video_keyframe_every_second.mkv")

      assert MatroskaCues.keyframe_times(path) == {:ok, [0.0, 1.0, 2.0, 3.0]}
    end

    @tag :tmp_dir
    test "returns an error for a file that isn't Matroska", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "movie.mp4")
      File.write!(path, <<0, 0, 0, 32>> <> "ftypisom" <> :crypto.strong_rand_bytes(1024))

      assert MatroskaCues.keyframe_times(path) == :error
    end
  end
end
