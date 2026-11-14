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

  @keyframe_seconds [0.0, 2.002, 4.004]

  describe "apply/1 —movie" do
    @tag :tmp_dir
    test "probes the file and populates the structure with video, audio, and subtitle tracks",
         %{tmp_dir: tmp_dir} do
      stub_ffprobe(load_fixture("video_friends_s01e01"))

      candidate = Candidate.new(video_file!(tmp_dir), :movie)
      keyframe_seconds = @keyframe_seconds

      assert {:ok,
              %Candidate{
                media_structure: %MediaStructure{
                  container: "matroska,webm",
                  duration_seconds: 1369.312,
                  bit_rate: 3_030_460,
                  keyframe_seconds: ^keyframe_seconds,
                  video_tracks: [
                    %VideoTrack{
                      codec: "hevc",
                      profile: "Main",
                      level: 120,
                      width: 1920,
                      height: 1080
                    }
                  ],
                  audio_tracks: [
                    %AudioTrack{codec: "eac3", language: "eng", channels: 6},
                    %AudioTrack{codec: "eac3", language: "fre", channels: 2}
                  ],
                  text_tracks: [%TextTrack{codec: "subrip", language: "fr"}]
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

    @tag :tmp_dir
    test "reads the keyframes of the Default Video Track", %{tmp_dir: tmp_dir} do
      metadata = load_fixture("video_friends_s01e01")
      [video | _other_streams] = metadata["streams"]
      # A cover picture before the default video
      picture = %{video | "index" => 0, "disposition" => %{"default" => 0, "attached_pic" => 1}}
      streams = [picture | Enum.map(metadata["streams"], &%{&1 | "index" => &1["index"] + 1})]
      stub_ffprobe(%{metadata | "streams" => streams})
      expect(ProbeMock, :keyframes, fn _path, 1 -> {:ok, @keyframe_seconds} end)

      candidate = Candidate.new(video_file!(tmp_dir), :movie)

      assert {:ok, _candidate} = ExtractStructure.apply(candidate)
    end

    @tag :tmp_dir
    test "returns an error when the keyframes can't be read", %{tmp_dir: tmp_dir} do
      stub_ffprobe(load_fixture("video_friends_s01e01"))

      stub(ProbeMock, :keyframes, fn _path, _stream_index ->
        {:error, "ffprobe found no keyframes"}
      end)

      candidate = Candidate.new(video_file!(tmp_dir), :movie)

      assert ExtractStructure.apply(candidate) == {:error, "ffprobe found no keyframes"}
    end

    @tag :tmp_dir
    test "reads the language, region, forced and SDH of the Text Tracks from their titles too",
         %{tmp_dir: tmp_dir} do
      stub_ffprobe(
        video_metadata([
          audio("fre"),
          subtitles("fre", "VFQ"),
          subtitles("fre", "French (fr-CA)"),
          subtitles("spa", "Español (Latinoamérica)"),
          subtitles(nil, "English SDH"),
          subtitles("eng", "English", %{"hearing_impaired" => 1}),
          subtitles("fre", "Forced"),
          subtitles("fre", "Full", %{"forced" => 1}),
          subtitles("eng", "Signs.2002.1080p.BluRay.x264-GROUP"),
          subtitles("eng", "English - Forced - 1080p")
        ])
      )

      {:ok, candidate} = ExtractStructure.apply(Candidate.new(video_file!(tmp_dir), :movie))

      assert [
               %TextTrack{language: "fr-CA", forced?: false, sdh?: false},
               %TextTrack{language: "fr-CA", forced?: false, sdh?: false},
               %TextTrack{language: "es-419", forced?: false, sdh?: false},
               %TextTrack{language: "en", forced?: false, sdh?: true},
               %TextTrack{language: "en", forced?: false, sdh?: true},
               %TextTrack{language: "fr", forced?: true, sdh?: false},
               %TextTrack{language: "fr", forced?: false, sdh?: false},
               %TextTrack{language: "en", forced?: false, sdh?: false},
               %TextTrack{language: "en", forced?: true, sdh?: false}
             ] = candidate.media_structure.text_tracks
    end

    @tag :tmp_dir
    test "counts a Text Track marked forced as full when no Audio Track is in its language",
         %{tmp_dir: tmp_dir} do
      stub_ffprobe(
        video_metadata([
          audio("spa"),
          subtitles("eng", "English", %{"forced" => 1}),
          subtitles("spa", "Spanish", %{"forced" => 1})
        ])
      )

      {:ok, candidate} = ExtractStructure.apply(Candidate.new(video_file!(tmp_dir), :movie))

      assert [
               %TextTrack{language: "en", forced?: false},
               %TextTrack{language: "es", forced?: true}
             ] = candidate.media_structure.text_tracks
    end

    @tag :tmp_dir
    test "counts a Text Track marked forced as full from the lines per minute the file counts",
         %{tmp_dir: tmp_dir} do
      forced = %{"forced" => 1}

      [
        audio("eng"),
        subtitles("eng", "English", forced, %{"NUMBER_OF_FRAMES-eng" => "10"}),
        subtitles("fre", "French", forced, %{"NUMBER_OF_FRAMES" => "8"}),
        subtitles("eng", "English Forced", forced, %{"NUMBER_OF_FRAMES" => "12"}),
        subtitles("fre", "French Full", forced, %{"NUMBER_OF_FRAMES" => "2"}),
        subtitles("eng", "English", %{}, %{"NUMBER_OF_FRAMES" => "2"})
      ]
      |> video_metadata()
      |> put_in(["format", "duration"], "120.0")
      |> stub_ffprobe()

      {:ok, candidate} = ExtractStructure.apply(Candidate.new(video_file!(tmp_dir), :movie))

      assert [
               %TextTrack{language: "en", forced?: false},
               %TextTrack{language: "fr", forced?: true},
               %TextTrack{language: "en", forced?: true},
               %TextTrack{language: "fr", forced?: false},
               %TextTrack{language: "en", forced?: false}
             ] = candidate.media_structure.text_tracks
    end

    @tag :tmp_dir
    test "reads the language, region, forced and SDH of sidecar Text Tracks from their names",
         %{tmp_dir: tmp_dir} do
      stub_ffprobe(video_metadata([audio("eng")]))
      path = video_file!(tmp_dir)

      for suffix <- ~w(da en.hi hi pt-BR.forced) do
        File.write!(Path.join(tmp_dir, "Friends - S01E01.#{suffix}.srt"), "")
      end

      {:ok, candidate} = ExtractStructure.apply(Candidate.new(path, :movie))

      assert [
               %TextTrack{language: "da", forced?: false, sdh?: false},
               %TextTrack{language: "en", forced?: false, sdh?: true},
               %TextTrack{language: "hi", forced?: false, sdh?: false},
               %TextTrack{language: "pt-BR", forced?: true, sdh?: false}
             ] = candidate.media_structure.text_tracks
    end

    test "returns an error when the file can't be read" do
      stub_ffprobe(load_fixture("video_friends_s01e01"))

      candidate = Candidate.new("/library/missing.mkv", :movie)

      assert {:error, _reason} = ExtractStructure.apply(candidate)
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
    test "returns an error when ffprobe returns an error" do
      stub(ProbeMock, :probe, fn _path -> {:error, "ffprobe exited with 1"} end)

      candidate = Candidate.new("/library/broken.mkv", :movie)

      assert {:error, _reason} = ExtractStructure.apply(candidate)
    end
  end

  # Bigger than both ends the File Fingerprint reads
  defp video_file!(dir) do
    path = Path.join(dir, "Friends - S01E01.mkv")
    File.write!(path, :crypto.strong_rand_bytes(200 * 1024))
    path
  end

  defp video_metadata(streams) do
    %{
      "format" => %{"format_name" => "matroska,webm", "duration" => "60.0"},
      "streams" => [
        %{"codec_type" => "video", "codec_name" => "h264", "width" => 1920, "height" => 1080}
        | streams
      ]
    }
  end

  defp audio(language),
    do: %{"codec_type" => "audio", "codec_name" => "ac3", "tags" => %{"language" => language}}

  defp subtitles(language, title, disposition \\ %{}, tags \\ %{}) do
    %{
      "codec_type" => "subtitle",
      "codec_name" => "subrip",
      "tags" => Map.merge(%{"language" => language, "title" => title}, tags),
      "disposition" => disposition
    }
  end

  defp stub_ffprobe(metadata) do
    stub(ProbeMock, :probe, fn _path -> {:ok, metadata} end)
    stub(ProbeMock, :keyframes, fn _path, _stream_index -> {:ok, @keyframe_seconds} end)
  end

  defp load_fixture(name) do
    Path.join([__DIR__, "../../../../support/fixtures/ffprobe", "#{name}.json"])
    |> File.read!()
    |> Jason.decode!()
  end
end
