defmodule WatchClub.FfmpegTest do
  use ExUnit.Case, async: true

  alias WatchClub.Ffmpeg

  @moduletag :tmp_dir

  # 13 seconds of 25 fps video with B-frames and a keyframe every 2 seconds, and 44.1 kHz audio
  setup %{tmp_dir: tmp_dir} do
    source_path = Path.join(tmp_dir, "source.mkv")

    {_output, 0} =
      System.cmd(
        "ffmpeg",
        ~w(-hide_banner -loglevel error -f lavfi -i testsrc2=size=160x120:rate=25:duration=13
           -f lavfi -i sine=sample_rate=44100:duration=13 -c:v libx264 -preset ultrafast -bf 2
           -g 50 -keyint_min 50 -sc_threshold 0 -c:a flac) ++ [source_path],
        stderr_to_stdout: true
      )

    %{source_path: source_path}
  end

  # From the keyframe at 6 seconds to the one at 12
  @segment %{stream_index: 0, start_time: 6.0, end_time: 12.0}

  describe "copy_video_segment/1" do
    test "keeps the frames from its keyframe to the next segment's",
         %{tmp_dir: tmp_dir, source_path: source_path} do
      {:ok, path} =
        Ffmpeg.copy_video_segment(
          Map.merge(@segment, %{
            source_path: source_path,
            output_path: Path.join(tmp_dir, "video.ts")
          })
        )

      assert frame_times(path) == Enum.map(150..299, &(&1 / 25))
    end
  end

  describe "transcode_video_segment/1" do
    test "keeps the frames from its keyframe to the next segment's",
         %{tmp_dir: tmp_dir, source_path: source_path} do
      {:ok, path} =
        Ffmpeg.transcode_video_segment(
          Map.merge(@segment, %{
            source_path: source_path,
            output_path: Path.join(tmp_dir, "video.ts"),
            width: 160,
            height: 120,
            video_bitrate: 200_000
          })
        )

      assert frame_times(path) == Enum.map(150..299, &(&1 / 25))
    end
  end

  describe "transcode_audio_segment/1" do
    test "starts at its time in the Video, where the previous segment ends",
         %{tmp_dir: tmp_dir, source_path: source_path} do
      transcode = fn start_time, end_time ->
        {:ok, path} =
          Ffmpeg.transcode_audio_segment(%{
            source_path: source_path,
            output_path: Path.join(tmp_dir, "audio_#{start_time}.ts"),
            start_time: start_time,
            end_time: end_time,
            stream_index: 1
          })

        timing(path)
      end

      previous = transcode.(0.0, 6.0)
      segment = transcode.(6.0, 12.0)

      # The AAC frame boundary closest to 6 seconds
      assert segment.start == 5.994667
      assert_in_delta previous.start + previous.duration, segment.start, 0.000_001
    end
  end

  defp frame_times(path) do
    {output, 0} =
      System.cmd("ffprobe", ~w(-v error -show_entries packet=pts_time -of csv=p=0) ++ [path])

    # A packet with side data lists them after its time
    output
    |> String.split("\n", trim: true)
    |> Enum.map(fn line -> line |> String.split(",") |> hd() |> String.to_float() end)
    |> Enum.sort()
  end

  defp timing(path) do
    {:ok, %{"streams" => [stream]}} = Ffmpeg.probe(path)
    %{start: String.to_float(stream["start_time"]), duration: String.to_float(stream["duration"])}
  end
end
