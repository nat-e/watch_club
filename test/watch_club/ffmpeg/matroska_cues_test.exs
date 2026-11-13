defmodule WatchClub.Ffmpeg.MatroskaCuesTest do
  use ExUnit.Case, async: true

  alias WatchClub.Ffmpeg.MatroskaCues

  # Stream 0 is audio, stream 1 video with a keyframe every second
  @fixture Path.join([
             __DIR__,
             "../../support/fixtures/matroska/audio_then_video_keyframe_every_second.mkv"
           ])

  describe "keyframe_times/2" do
    test "lists the keyframes of the video stream" do
      assert MatroskaCues.keyframe_times(@fixture, 1) == {:ok, [0.0, 1.0, 2.0, 3.0]}
    end

    test "returns an error for a stream that isn't video" do
      assert MatroskaCues.keyframe_times(@fixture, 0) == :error
    end

    @tag :tmp_dir
    test "returns an error when the Cues can't be read to their end", %{tmp_dir: tmp_dir} do
      data = File.read!(@fixture)
      # The last CuePoint claims one byte more than the Cues hold
      {cue_point, _length} = data |> :binary.matches(<<0xBB, 0x90, 0xB3>>) |> List.last()
      path = Path.join(tmp_dir, "damaged.mkv")

      File.write!(path, [
        binary_part(data, 0, cue_point + 1),
        0x91,
        binary_part(data, cue_point + 2, byte_size(data) - cue_point - 2)
      ])

      assert MatroskaCues.keyframe_times(path, 1) == :error
    end

    @tag :tmp_dir
    test "returns an error for a file that isn't Matroska", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "movie.avi")

      File.write!(
        path,
        "RIFF" <> <<4096::little-32>> <> "AVI " <> :crypto.strong_rand_bytes(4096)
      )

      assert MatroskaCues.keyframe_times(path, 0) == :error
    end
  end
end
