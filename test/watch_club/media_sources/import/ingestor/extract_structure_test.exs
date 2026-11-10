defmodule WatchClub.MediaSources.Import.Ingestor.ExtractStructureTest do
  use ExUnit.Case, async: true

  import Mox

  alias WatchClub.Ffmpeg.ProbeMock
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MediaStructure

  alias WatchClub.MediaSources.Import.Candidate.MediaStructure.{
    AudioTrack,
    TextTrack,
    VideoTrack
  }

  alias WatchClub.MediaSources.Import.Ingestor.ExtractStructure

  setup :verify_on_exit!

  describe "apply/1 —movie" do
    @tag :tmp_dir
    test "probes the file and populates the structure with video, audio, and subtitle tracks",
         %{tmp_dir: tmp_dir} do
      stub_ffprobe(load_fixture("video_friends_s01e01"))

      candidate = Candidate.new(video_file!(tmp_dir), :movie)

      assert {:ok,
              %Candidate{
                media_structure: %MediaStructure{
                  container: "matroska,webm",
                  duration_seconds: 1369.312,
                  bit_rate: 3_030_460,
                  video_tracks: [%VideoTrack{codec: "hevc", width: 1920, height: 1080}],
                  audio_tracks: [
                    %AudioTrack{codec: "eac3", language: "eng", channels: 6},
                    %AudioTrack{codec: "eac3", language: "fre", channels: 2}
                  ],
                  text_tracks: [%TextTrack{codec: "subrip", language: "fre"}]
                }
              }} = ExtractStructure.apply(candidate)
    end

    @tag :tmp_dir
    test "gives the file a File Fingerprint that changes with either end of the file",
         %{tmp_dir: tmp_dir} do
      stub_ffprobe(load_fixture("video_friends_s01e01"))
      path = video_file!(tmp_dir)

      fingerprint = fn ->
        {:ok, candidate} = ExtractStructure.apply(Candidate.new(path, :movie))
        candidate.media_structure.file_fingerprint
      end

      original = fingerprint.()
      assert fingerprint.() == original

      # Same size, last byte replaced
      File.open!(path, [:read, :write, :binary], &:file.pwrite(&1, {:eof, -1}, "x"))
      refute fingerprint.() == original
    end

    test "skips the file when it can't be read" do
      stub_ffprobe(load_fixture("video_friends_s01e01"))

      candidate = Candidate.new("/library/missing.mkv", :movie)

      assert ExtractStructure.apply(candidate) == :skip
    end
  end

  describe "apply/1 —tv_show_episode" do
    @tag :tmp_dir
    test "uses the same video probing as movies", %{tmp_dir: tmp_dir} do
      stub_ffprobe(load_fixture("video_friends_s01e01"))

      candidate = Candidate.new(video_file!(tmp_dir), :tv_show_episode)

      assert {:ok,
              %Candidate{
                media_structure: %MediaStructure{
                  video_tracks: [%VideoTrack{codec: "hevc"}],
                  audio_tracks: [_, _],
                  text_tracks: [_]
                }
              }} = ExtractStructure.apply(candidate)
    end
  end

  describe "apply/1 —audiobook" do
    test "probes the file and populates an audio-only structure" do
      stub_ffprobe(load_fixture("audiobook_inner_game"))

      candidate = Candidate.new("/library/audiobook.mp3", :audiobook)

      assert {:ok,
              %Candidate{
                media_structure: %MediaStructure{
                  container: "mp3",
                  duration_seconds: 180.574378,
                  bit_rate: 67_476,
                  video_tracks: [],
                  audio_tracks: [%AudioTrack{codec: "mp3", channels: 2}],
                  text_tracks: []
                }
              }} = ExtractStructure.apply(candidate)
    end
  end

  describe "apply/1 —ebook" do
    test "uses the file extension as container without probing" do
      candidate = Candidate.new("/library/book.epub", :ebook)

      assert {:ok,
              %Candidate{
                media_structure: %MediaStructure{
                  container: "epub",
                  video_tracks: [],
                  audio_tracks: [],
                  text_tracks: []
                }
              }} = ExtractStructure.apply(candidate)
    end
  end

  describe "apply/1 —failure" do
    test "skips the file when ffprobe returns an error" do
      stub(ProbeMock, :probe, fn _path -> {:error, "ffprobe exited with 1"} end)

      candidate = Candidate.new("/library/broken.mkv", :movie)

      assert ExtractStructure.apply(candidate) == :skip
    end
  end

  # Bigger than both ends the File Fingerprint reads
  defp video_file!(dir) do
    path = Path.join(dir, "Friends - S01E01.mkv")
    File.write!(path, :crypto.strong_rand_bytes(200 * 1024))
    path
  end

  defp stub_ffprobe(metadata) do
    stub(ProbeMock, :probe, fn _path -> {:ok, metadata} end)
  end

  defp load_fixture(name) do
    Path.join([__DIR__, "../../../../support/fixtures/ffprobe", "#{name}.json"])
    |> File.read!()
    |> Jason.decode!()
  end
end
