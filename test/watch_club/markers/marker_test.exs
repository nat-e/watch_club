defmodule WatchClub.Markers.MarkerTest do
  use WatchClub.DataCase, async: false

  import Mox

  alias WatchClub.Ffmpeg.ProbeMock
  alias WatchClub.Markers
  alias WatchClub.SystemActor

  # Chromaprint gives a point every 4096 / 3 samples at 11025 Hz
  @seconds_per_point 4096 / 3 / 11_025

  describe "detect_season_markers/*" do
    @describetag :tmp_dir

    test "finds the Markers in the named chapters", %{tmp_dir: tmp_dir} do
      {show_id, [video]} = season_videos(1, tmp_dir)

      stub_chapters(%{
        video.media.path => [
          chapter(0, 45, "Recap"),
          chapter(45, 70, "2. Title Sequence & Opening Credits"),
          chapter(70, 80, "Opening Credits"),
          chapter(80, 1250, "Scene 3"),
          chapter(1250, 1320, "End Credits")
        ]
      })

      Markers.detect_season_markers!(show_id, 1, actor: SystemActor.actor())

      assert markers(video) == [
               credits: {1250.0, 1320.0},
               intro: {45.0, 80.0},
               recap: {0.0, 45.0}
             ]
    end

    test "gives the episodes the Intro and Credits they share", %{tmp_dir: tmp_dir} do
      {show_id, [first, second, third]} = season_videos(3, tmp_dir)
      stub_chapters(%{})

      stub_fingerprints(%{
        first.media.path => [{:first, 100}, {:theme, 320}],
        second.media.path => [{:second, 500}, {:theme, 320}],
        third.media.path => [{:third, 300}, {:theme, 320}]
      })

      Markers.detect_season_markers!(show_id, 1, actor: SystemActor.actor())

      assert_markers(first, intro: range(100, 320), credits: credits())
      assert_markers(second, intro: range(500, 320), credits: credits())
      assert_markers(third, intro: range(300, 320), credits: credits())
    end

    test "gives an episode the longest audio it shares with another", %{tmp_dir: tmp_dir} do
      {show_id, [first, second, third]} = season_videos(3, tmp_dir)
      stub_chapters(%{})

      stub_fingerprints(%{
        first.media.path => [{:first, 100}, {:jingle, 160}],
        second.media.path => [{:jingle, 160}, {:second, 100}, {:theme, 320}],
        third.media.path => [{:third, 300}, {:theme, 320}]
      })

      Markers.detect_season_markers!(show_id, 1, actor: SystemActor.actor())

      assert_markers(first, intro: range(100, 160))
      assert_markers(second, intro: range(260, 320))
      assert_markers(third, intro: range(300, 320))
    end

    test "leaves out the episodes of other seasons", %{tmp_dir: tmp_dir} do
      show = generate(tv_show(num_seasons: 2, episodes_per_season: 2))

      [first, second, next_season] =
        show.tv_show.episodes
        |> Enum.sort_by(&{&1.season_number, &1.episode_number})
        |> Enum.take(3)
        |> Enum.map(&video(&1, tmp_dir))

      stub_chapters(%{})

      stub_fingerprints(%{
        first.media.path => [{:first, 100}, {:theme, 320}],
        second.media.path => [{:second, 500}, {:theme, 320}],
        next_season.media.path => [{:next_season, 300}, {:theme, 320}]
      })

      Markers.detect_season_markers!(show.id, 1, actor: SystemActor.actor())

      assert_markers(first, intro: range(100, 320), credits: credits())
      assert_markers(second, intro: range(500, 320), credits: credits())
      assert markers(next_season) == []
    end

    test "keeps the Markers of the named chapters", %{tmp_dir: tmp_dir} do
      {show_id, [first, second]} = season_videos(2, tmp_dir)
      stub_chapters(%{first.media.path => [chapter(30, 60, "Intro")]})

      stub_fingerprints(%{
        first.media.path => [{:first, 100}, {:theme, 320}],
        second.media.path => [{:second, 500}, {:theme, 320}]
      })

      Markers.detect_season_markers!(show_id, 1, actor: SystemActor.actor())

      assert_markers(first, intro: {30.0, 60.0}, credits: credits())
      assert_markers(second, intro: range(500, 320), credits: credits())
    end

    test "doesn't compare the Videos of one episode", %{tmp_dir: tmp_dir} do
      show = generate(tv_show(num_seasons: 1, episodes_per_season: 1))
      [episode] = show.tv_show.episodes
      first = video(episode, tmp_dir)
      second = video(episode, tmp_dir)
      stub_chapters(%{})

      stub_fingerprints(%{
        first.media.path => [{:theme, 320}],
        second.media.path => [{:theme, 320}]
      })

      Markers.detect_season_markers!(show.id, 1, actor: SystemActor.actor())

      assert markers(first) == []
      assert markers(second) == []
    end

    test "keeps the Markers of a Video whose file can't be read", %{tmp_dir: tmp_dir} do
      {show_id, [unreadable, readable]} = season_videos(2, tmp_dir)

      chapters = [chapter(30, 60, "Intro"), chapter(1250, 1320, "Credits")]
      stub_chapters(%{unreadable.media.path => chapters, readable.media.path => chapters})
      Markers.detect_season_markers!(show_id, 1, actor: SystemActor.actor())

      stub(ProbeMock, :probe, fn
        path when path == unreadable.media.path -> {:error, "Invalid data found"}
        _path -> {:ok, %{"chapters" => []}}
      end)

      Markers.detect_season_markers!(show_id, 1, actor: SystemActor.actor())

      assert markers(unreadable) == [credits: {1250.0, 1320.0}, intro: {30.0, 60.0}]
      assert markers(readable) == []
    end

    test "keeps the Markers of a Video whose audio can't be read", %{tmp_dir: tmp_dir} do
      {show_id, [unreadable, first, second]} = season_videos(3, tmp_dir)

      chapters = [chapter(30, 60, "Intro"), chapter(1250, 1320, "Credits")]
      stub_chapters(Map.new([unreadable, first, second], &{&1.media.path, chapters}))
      Markers.detect_season_markers!(show_id, 1, actor: SystemActor.actor())

      stub_chapters(%{})

      stub_fingerprints(%{
        first.media.path => [{:first, 100}, {:theme, 320}],
        second.media.path => [{:second, 500}, {:theme, 320}]
      })

      Markers.detect_season_markers!(show_id, 1, actor: SystemActor.actor())

      assert markers(unreadable) == [credits: {1250.0, 1320.0}, intro: {30.0, 60.0}]
      assert_markers(first, intro: range(100, 320), credits: credits())
      assert_markers(second, intro: range(500, 320), credits: credits())
    end

    test "finds no Markers for an episode alone in its season, without chapters",
         %{tmp_dir: tmp_dir} do
      {show_id, [video]} = season_videos(1, tmp_dir)
      stub_chapters(%{})

      Markers.detect_season_markers!(show_id, 1, actor: SystemActor.actor())

      assert markers(video) == []
    end

    test "forbids Users", %{tmp_dir: tmp_dir} do
      {show_id, _videos} = season_videos(1, tmp_dir)

      show_id
      |> Markers.detect_season_markers(1, actor: generate(user()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "detect_movie_markers/*" do
    @describetag :tmp_dir

    test "finds the Markers in the named chapters of the Movie's Videos", %{tmp_dir: tmp_dir} do
      movie = generate(movie())
      [first, second] = [video(movie, tmp_dir), video(movie, tmp_dir)]

      stub_chapters(%{
        first.media.path => [chapter(6000, 6300, "End Credits")],
        second.media.path => [chapter(0, 30, "Opening Credits")]
      })

      Markers.detect_movie_markers!(movie.id, actor: SystemActor.actor())

      assert markers(first) == [credits: {6000.0, 6300.0}]
      assert markers(second) == [intro: {0.0, 30.0}]
    end

    test "forbids Users" do
      generate(movie()).id
      |> Markers.detect_movie_markers(actor: generate(user()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  # The Videos of the episodes of the first season of a new TV Show
  defp season_videos(count, tmp_dir) do
    show = generate(tv_show(num_seasons: 1, episodes_per_season: count))

    videos =
      show.tv_show.episodes
      |> Enum.sort_by(& &1.episode_number)
      |> Enum.map(&video(&1, tmp_dir))

    {show.id, videos}
  end

  # Their fingerprints of the end start 990 seconds in: they cover a quarter of the Video. The
  # cache of fingerprints needs the file.
  defp video(movie_or_episode, tmp_dir) do
    path = Path.join(tmp_dir, "#{System.unique_integer([:positive])}.mkv")
    File.write!(path, "")

    generate(video_media(movie_or_episode, path: path, video: %{duration_seconds: 1320.0}))
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
  # of points. Its fingerprint of the end has 400 points of credits music after 2000 points. The
  # audio of the other Videos can't be read.
  defp stub_fingerprints(beginnings) do
    stub(ProbeMock, :audio_fingerprint, fn path, from_seconds, _seconds ->
      cond do
        not Map.has_key?(beginnings, path) -> {:error, "Invalid data found"}
        from_seconds == 0 -> {:ok, Enum.flat_map(beginnings[path], fn {n, p} -> sound(n, p) end)}
        true -> {:ok, sound({path, :end}, 2000) ++ sound(:credits, 400)}
      end
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
