defmodule WatchClub.Ffmpeg.MatroskaCuesTest do
  use ExUnit.Case, async: true

  alias WatchClub.Ffmpeg.MatroskaCues

  # Stream 0 is audio, stream 1 video with a keyframe every second
  @fixture Path.join([
             __DIR__,
             "../../support/fixtures/matroska/audio_then_video_keyframe_every_second.mkv"
           ])

  describe "keyframes/2" do
    test "lists the keyframes of the video stream, with the bytes to the next one" do
      assert MatroskaCues.keyframes(@fixture, 1) ==
               {:ok, [{0.0, 5669}, {1.0, 5174}, {2.0, 5269}, {3.0, 5366}]}
    end

    test "returns an error for a stream that isn't video" do
      assert MatroskaCues.keyframes(@fixture, 0) == :error
    end

    @tag :tmp_dir
    test "returns an error when a CuePoint runs past the end of the Cues", %{tmp_dir: tmp_dir} do
      # The last CuePoint claims one byte more than the Cues hold
      path = damage!(tmp_dir, <<0xBB, 0x90, 0xB3>>, <<0xBB, 0x91, 0xB3>>)

      assert MatroskaCues.keyframes(path, 1) == :error
    end

    @tag :tmp_dir
    test "returns an error when a CuePoint doesn't say its track", %{tmp_dir: tmp_dir} do
      # The last CueTrack becomes a Void element of the same size
      path = damage!(tmp_dir, <<0xF7, 0x81, 0x02>>, <<0xEC, 0x81, 0x00>>)

      assert MatroskaCues.keyframes(path, 1) == :error
    end

    @tag :tmp_dir
    test "returns an error when a CuePoint of the stream doesn't say where in its Cluster",
         %{tmp_dir: tmp_dir} do
      # The last CueRelativePosition becomes a Void element of the same size
      path = damage!(tmp_dir, <<0xF0, 0x81, 0x39>>, <<0xEC, 0x81, 0x00>>)

      assert MatroskaCues.keyframes(path, 1) == :error
    end

    @tag :tmp_dir
    test "returns an error when the last Cluster's size is unknown", %{tmp_dir: tmp_dir} do
      path =
        damage!(
          tmp_dir,
          <<0x1F, 0x43, 0xB6, 0x75, 0x55, 0x29>>,
          <<0x1F, 0x43, 0xB6, 0x75, 0x7F, 0xFF>>
        )

      assert MatroskaCues.keyframes(path, 1) == :error
    end

    @tag :tmp_dir
    test "returns an error when the timestamp scale is zero", %{tmp_dir: tmp_dir} do
      path =
        damage!(
          tmp_dir,
          <<0x2A, 0xD7, 0xB1, 0x83, 0x0F, 0x42, 0x40>>,
          <<0x2A, 0xD7, 0xB1, 0x83, 0, 0, 0>>
        )

      assert MatroskaCues.keyframes(path, 1) == :error
    end

    @tag :tmp_dir
    test "returns an error for a file that isn't Matroska", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "movie.avi")

      File.write!(
        path,
        "RIFF" <> <<4096::little-32>> <> "AVI " <> :crypto.strong_rand_bytes(4096)
      )

      assert MatroskaCues.keyframes(path, 0) == :error
    end
  end

  # A copy of the fixture with the last `bytes` replaced
  defp damage!(tmp_dir, bytes, replacement) do
    data = File.read!(@fixture)
    {position, length} = data |> :binary.matches(bytes) |> List.last()
    path = Path.join(tmp_dir, "damaged.mkv")

    File.write!(path, [
      binary_part(data, 0, position),
      replacement,
      binary_part(data, position + length, byte_size(data) - position - length)
    ])

    path
  end
end
