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
  alias WatchClub.MediaSources.{Import, Source}

  setup :verify_on_exit!

  describe "apply/2 — movie" do
    test "probes the file and populates the structure with video, audio, and subtitle tracks" do
      stub_ffprobe(load_fixture("video_friends_s01e01"))

      candidate = Candidate.new("/library/Friends - S01E01.mkv")
      run = run_for(:movie)

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
              }} = ExtractStructure.apply(candidate, run)
    end
  end

  describe "apply/2 — tv_show_episode" do
    test "uses the same video probing as movies" do
      stub_ffprobe(load_fixture("video_friends_s01e01"))

      candidate = Candidate.new("/library/Friends - S01E01.mkv")
      run = run_for(:tv_show_episode)

      assert {:ok,
              %Candidate{
                media_structure: %MediaStructure{
                  video_tracks: [%VideoTrack{codec: "hevc"}],
                  audio_tracks: [_, _],
                  text_tracks: [_]
                }
              }} = ExtractStructure.apply(candidate, run)
    end
  end

  describe "apply/2 — audiobook" do
    test "probes the file and populates an audio-only structure" do
      stub_ffprobe(load_fixture("audiobook_inner_game"))

      candidate = Candidate.new("/library/audiobook.mp3")
      run = run_for(:audiobook)

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
              }} = ExtractStructure.apply(candidate, run)
    end
  end

  describe "apply/2 — ebook" do
    test "uses the file extension as container without probing" do
      candidate = Candidate.new("/library/book.epub")
      run = run_for(:ebook)

      assert {:ok,
              %Candidate{
                media_structure: %MediaStructure{
                  container: "epub",
                  video_tracks: [],
                  audio_tracks: [],
                  text_tracks: []
                }
              }} = ExtractStructure.apply(candidate, run)
    end
  end

  describe "apply/2 — failure" do
    test "halts when ffprobe returns an error" do
      stub(ProbeMock, :probe, fn _path -> {:error, "ffprobe exited with 1"} end)

      candidate = Candidate.new("/library/broken.mkv")
      run = run_for(:movie)

      assert {:halt, "ffprobe exited with 1"} = ExtractStructure.apply(candidate, run)
    end
  end

  defp stub_ffprobe(metadata) do
    stub(ProbeMock, :probe, fn _path -> {:ok, metadata} end)
  end

  defp load_fixture(name) do
    Path.join([__DIR__, "../../../../support/fixtures/ffprobe", "#{name}.json"])
    |> File.read!()
    |> Jason.decode!()
  end

  defp run_for(media_type) do
    %Import{
      media_source: %Source{
        media_type: media_type,
        source_type: :filesystem,
        implementation: %WatchClub.MediaSources.Filesystem{filesystem_path: "/library"}
      }
    }
  end
end
