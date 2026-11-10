defmodule WatchClub.Markers.MarkerTest do
  use WatchClub.DataCase, async: false

  import Mox

  alias WatchClub.Ffmpeg.ProbeMock
  alias WatchClub.Markers
  alias WatchClub.SystemActor

  # Chromaprint gives a point every 4096 / 3 samples at 11025 Hz
  @seconds_per_point 4096 / 3 / 11_025

  describe "detect_markers/*" do
    @describetag :tmp_dir

    test "finds the Markers in the named chapters", %{tmp_dir: tmp_dir} do
      [video] = episode_videos(1, tmp_dir)

      stub_chapters(%{
        video.media.path => [
          chapter(0, 45, "Recap"),
          chapter(45, 70, "2. Title Sequence & Opening Credits"),
          chapter(70, 80, "Opening Credits"),
          chapter(80, 1250, "Scene 3"),
          chapter(1250, 1320, "End Credits")
        ]
      })

      Markers.detect_markers!([video], actor: SystemActor.actor())

      assert markers(video) == [
               credits: {1250.0, 1320.0},
               intro: {45.0, 80.0},
               recap: {0.0, 45.0}
             ]
    end

    test "gives the episodes the Intro and Credits they share", %{tmp_dir: tmp_dir} do
      [first, second, third] = episode_videos(3, tmp_dir)
      stub_chapters(%{})

      stub_fingerprints(%{
        first.media.path => [{:first, 100}, {:theme, 320}],
        second.media.path => [{:second, 500}, {:theme, 320}],
        third.media.path => [{:third, 300}, {:theme, 320}]
      })

      Markers.detect_markers!([first, second, third], actor: SystemActor.actor())

      assert_markers(first, intro: range(100, 320), credits: credits())
      assert_markers(second, intro: range(500, 320), credits: credits())
      assert_markers(third, intro: range(300, 320), credits: credits())
    end

    test "gives an episode the longest audio it shares with another", %{tmp_dir: tmp_dir} do
      [first, second, third] = episode_videos(3, tmp_dir)
      stub_chapters(%{})

      stub_fingerprints(%{
        first.media.path => [{:first, 100}, {:jingle, 160}],
        second.media.path => [{:jingle, 160}, {:second, 100}, {:theme, 320}],
        third.media.path => [{:third, 300}, {:theme, 320}]
      })

      Markers.detect_markers!([first, second, third], actor: SystemActor.actor())

      assert_markers(first, intro: range(100, 160))
      assert_markers(second, intro: range(260, 320))
      assert_markers(third, intro: range(300, 320))
    end

    test "keeps the Markers of the named chapters", %{tmp_dir: tmp_dir} do
      [first, second] = episode_videos(2, tmp_dir)
      stub_chapters(%{first.media.path => [chapter(30, 60, "Intro")]})

      stub_fingerprints(%{
        first.media.path => [{:first, 100}, {:theme, 320}],
        second.media.path => [{:second, 500}, {:theme, 320}]
      })

      Markers.detect_markers!([first, second], actor: SystemActor.actor())

      assert_markers(first, intro: {30.0, 60.0}, credits: credits())
      assert_markers(second, intro: range(500, 320), credits: credits())
    end

    test "doesn't compare the Videos of one episode", %{tmp_dir: tmp_dir} do
      [episode] = episodes(1)
      first = episode_video(episode, tmp_dir)
      second = episode_video(episode, tmp_dir)
      stub_chapters(%{})

      stub_fingerprints(%{
        first.media.path => [{:theme, 320}],
        second.media.path => [{:theme, 320}]
      })

      Markers.detect_markers!([first, second], actor: SystemActor.actor())

      assert markers(first) == []
      assert markers(second) == []
    end

    test "keeps the Markers of a Video whose file can't be read", %{tmp_dir: tmp_dir} do
      [unreadable, readable] = episode_videos(2, tmp_dir)

      chapters = [chapter(30, 60, "Intro"), chapter(1250, 1320, "Credits")]
      stub_chapters(%{unreadable.media.path => chapters, readable.media.path => chapters})

      Markers.detect_markers!([unreadable, readable], actor: SystemActor.actor())

      stub(ProbeMock, :probe, fn
        path when path == unreadable.media.path -> {:error, "Invalid data found"}
        _path -> {:ok, %{"chapters" => []}}
      end)

      Markers.detect_markers!([unreadable, readable], actor: SystemActor.actor())

      assert markers(unreadable) == [credits: {1250.0, 1320.0}, intro: {30.0, 60.0}]
      assert markers(readable) == []
    end

    test "finds no Markers without chapters or other episodes", %{tmp_dir: tmp_dir} do
      [video] = episode_videos(1, tmp_dir)
      stub_chapters(%{})

      Markers.detect_markers!([video], actor: SystemActor.actor())

      assert markers(video) == []
    end

    test "forbids Users", %{tmp_dir: tmp_dir} do
      1
      |> episode_videos(tmp_dir)
      |> Markers.detect_markers(actor: generate(user()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp episodes(count) do
    generate(tv_show(num_seasons: 1, episodes_per_season: count)).tv_show.episodes
    |> Enum.sort_by(& &1.episode_number)
  end

  defp episode_videos(count, tmp_dir), do: Enum.map(episodes(count), &episode_video(&1, tmp_dir))

  # Their fingerprints of the end start 990 seconds in: they cover a quarter of the Video. The
  # cache of fingerprints needs the file.
  defp episode_video(episode, tmp_dir) do
    path = Path.join(tmp_dir, "#{System.unique_integer([:positive])}.mkv")
    File.write!(path, "")

    generate(video_media(episode, path: path, video: %{duration_seconds: 1320.0}))
    |> Ash.load!([video: :media], authorize?: false)
    |> Map.fetch!(:video)
  end

  defp stub_chapters(chapters) do
    stub(ProbeMock, :probe, fn path -> {:ok, %{"chapters" => Map.get(chapters, path, [])}} end)
  end

  defp chapter(start_seconds, end_seconds, title) do
    %{
      "start_time" => "#{start_seconds}.000000",
      "end_time" => "#{end_seconds}.000000",
      "tags" => %{"title" => title}
    }
  end

  # The fingerprint of each Video's beginning is made of the given sounds, as names and numbers
  # of points. Its fingerprint of the end has 400 points of credits music after 2000 points.
  defp stub_fingerprints(beginnings) do
    stub(ProbeMock, :audio_fingerprint, fn path, from_seconds, _seconds ->
      if from_seconds == 0,
        do: {:ok, Enum.flat_map(beginnings[path], fn {name, points} -> sound(name, points) end)},
        else: {:ok, sound({path, :end}, 2000) ++ sound(:credits, 400)}
    end)
  end

  defp sound(name, points), do: Enum.map(1..points, &:erlang.phash2({name, &1}, 4_294_967_296))

  defp range(start, points),
    do: {start * @seconds_per_point, (start + points) * @seconds_per_point}

  defp credits, do: {990 + 2000 * @seconds_per_point, 990 + 2400 * @seconds_per_point}

  defp markers(video) do
    video
    |> Ash.load!(:markers, authorize?: false)
    |> Map.fetch!(:markers)
    |> Enum.map(&{&1.kind, {&1.start_seconds, &1.end_seconds}})
    |> Enum.sort()
  end

  defp assert_markers(video, expected) do
    markers = markers(video)

    for {kind, {start_seconds, end_seconds}} <- expected do
      assert {actual_start, actual_end} = markers[kind]
      assert_in_delta actual_start, start_seconds, 0.01
      assert_in_delta actual_end, end_seconds, 0.01
    end
  end
end
