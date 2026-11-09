defmodule WatchClub.MediaCatalog.VideoTest do
  use WatchClub.DataCase, async: false

  import Mox

  alias WatchClub.Ffmpeg.ProbeMock
  alias WatchClub.MediaCatalog
  alias WatchClub.SystemActor

  # Chromaprint gives a point every 4096 / 3 samples at 11025 Hz
  @seconds_per_point 4096 / 3 / 11_025

  describe "detect_markers/*" do
    test "finds the Markers in the named chapters" do
      [episode] = episodes(1)
      video = episode_video(episode)

      stub(ProbeMock, :probe, fn _path ->
        {:ok,
         %{
           "chapters" => [
             chapter(0, 45, "Recap"),
             chapter(45, 70, "2. Title Sequence & Opening Credits"),
             chapter(70, 80, "Opening Credits"),
             chapter(80, 1250, "Scene 3"),
             chapter(1250, 1320, "End Credits")
           ]
         }}
      end)

      MediaCatalog.detect_markers!(video, actor: SystemActor.actor())

      assert markers(video) == [
               credits: {1250.0, 1320.0},
               intro: {45.0, 80.0},
               recap: {0.0, 45.0}
             ]
    end

    test "finds the Intro and Credits that the nearest episode shares, and gives them to it" do
      [first_episode, second_episode, _third] = episodes(3)
      first = episode_video(first_episode)
      second = episode_video(second_episode)
      stub(ProbeMock, :probe, fn _path -> {:ok, %{"chapters" => []}} end)
      stub_fingerprints(%{first.media.path => 100, second.media.path => 500})

      MediaCatalog.detect_markers!(second, actor: SystemActor.actor())

      assert_markers(second, intro: intro(500), credits: credits())
      assert_markers(first, intro: intro(100), credits: credits())
    end

    test "keeps the Markers that the nearest episode already has" do
      [first_episode, second_episode] = episodes(2)
      first = episode_video(first_episode)
      second = episode_video(second_episode)

      stub(ProbeMock, :probe, fn path ->
        chapters = if path == first.media.path, do: [chapter(30, 60, "Intro")], else: []
        {:ok, %{"chapters" => chapters}}
      end)

      stub_fingerprints(%{first.media.path => 100, second.media.path => 500})
      MediaCatalog.detect_markers!(first, actor: SystemActor.actor())

      MediaCatalog.detect_markers!(second, actor: SystemActor.actor())

      assert markers(first)[:intro] == {30.0, 60.0}
    end

    test "finds no Markers without chapters or other episodes" do
      [episode] = episodes(1)
      video = episode_video(episode)
      stub(ProbeMock, :probe, fn _path -> {:ok, %{"chapters" => []}} end)

      MediaCatalog.detect_markers!(video, actor: SystemActor.actor())

      assert markers(video) == []
    end

    test "forbids Users" do
      [episode] = episodes(1)

      episode
      |> episode_video()
      |> MediaCatalog.detect_markers(actor: generate(user()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp episodes(count) do
    generate(tv_show(num_seasons: 1, episodes_per_season: count)).tv_show.episodes
    |> Enum.sort_by(& &1.episode_number)
  end

  # Their fingerprints of the end start 990 seconds in: they cover a quarter of the Video
  defp episode_video(episode) do
    generate(video_media(episode, video: %{duration_seconds: 1320.0}))
    |> Ash.load!([video: :media], authorize?: false)
    |> Map.fetch!(:video)
  end

  defp chapter(start_seconds, end_seconds, title) do
    %{
      "start_time" => "#{start_seconds}.000000",
      "end_time" => "#{end_seconds}.000000",
      "tags" => %{"title" => title}
    }
  end

  # Each Video has a 320-point theme after the given number of points, and its fingerprint of
  # the end has 400 points of credits music after 2000 points
  defp stub_fingerprints(theme_starts) do
    stub(ProbeMock, :audio_fingerprint, fn path, from_seconds, _seconds ->
      if from_seconds == 0,
        do:
          {:ok,
           sound({path, :before}, theme_starts[path]) ++
             sound(:theme, 320) ++ sound({path, :after}, 1000)},
        else: {:ok, sound({path, :end}, 2000) ++ sound(:credits, 400)}
    end)
  end

  defp sound(name, points), do: Enum.map(1..points, &:erlang.phash2({name, &1}, 4_294_967_296))

  defp intro(theme_start),
    do: {theme_start * @seconds_per_point, (theme_start + 320) * @seconds_per_point}

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
