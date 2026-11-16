defmodule WatchClub.FfmpegTest do
  use ExUnit.Case, async: true

  alias WatchClub.Ffmpeg

  @moduletag :tmp_dir

  # 13 seconds of 25 fps video and 44.1 kHz audio
  setup %{tmp_dir: tmp_dir} do
    source_path = Path.join(tmp_dir, "source.mkv")

    {_output, 0} =
      System.cmd(
        "ffmpeg",
        ~w(-hide_banner -loglevel error -f lavfi -i testsrc2=size=160x120:rate=25:duration=13
           -f lavfi -i sine=sample_rate=44100:duration=13 -c:v libx264 -preset ultrafast -c:a flac) ++
          [source_path],
        stderr_to_stdout: true
      )

    %{source_path: source_path}
  end

  describe "transcode_video_segment/1" do
    test "starts at its time in the Video", %{tmp_dir: tmp_dir, source_path: source_path} do
      {:ok, path} =
        Ffmpeg.transcode_video_segment(%{
          source_path: source_path,
          output_path: Path.join(tmp_dir, "video.ts"),
          start_time: 6.0,
          end_time: 12.0,
          width: 160,
          height: 120,
          video_bitrate: 200_000
        })

      assert timing(path).start == 6.0
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

  defp timing(path) do
    {:ok, %{"streams" => [stream]}} = Ffmpeg.probe(path)
    %{start: String.to_float(stream["start_time"]), duration: String.to_float(stream["duration"])}
  end
end
