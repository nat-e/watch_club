defmodule WatchClub.Playbacks.ProblemReportTest do
  use WatchClub.DataCase, async: false

  import WatchClub.Playbacks

  describe "report_problem/*" do
    test "reports a Problem with the Video of the actor's Playback" do
      user = generate(user())
      playback = generate(playback(movie_media(), started_by: user))

      report =
        report_problem!(
          %{
            playback_id: playback.id,
            category: :subtitles,
            comment: "The subtitles are 2 seconds late",
            position_seconds: 2537.4,
            audio: "English",
            quality: "Auto, 720p",
            user_agent: "Mozilla/5.0 Firefox/133.0"
          },
          actor: user
        )

      assert report.playback_id == playback.id
      assert report.category == :subtitles
      assert report.comment == "The subtitles are 2 seconds late"
      assert report.position_seconds == 2537.4
      assert report.subtitles == nil
      assert report.archived_at == nil
    end

    test "forbids reporting a Problem about another User's Playback" do
      playback = generate(playback(movie_media()))

      report_problem(%{playback_id: playback.id, category: :audio}, actor: generate(user()))
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "rejects details longer than 1000 characters" do
      user = generate(user())
      playback = generate(playback(movie_media(), started_by: user))

      report_problem(
        %{playback_id: playback.id, category: :other, comment: String.duplicate("a", 1001)},
        actor: user
      )
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :comment} -> true
        _ -> false
      end)
    end
  end

  describe "archive_problem_report/*" do
    test "archives a Problem Report" do
      report = generate(problem_report(generate(playback(movie_media()))))

      report = archive_problem_report!(report, actor: generate(administrator()))

      assert %DateTime{} = report.archived_at
    end

    test "forbids Users other than the Instance Administrator" do
      user = generate(user())
      report = generate(problem_report(generate(playback(movie_media(), started_by: user))))

      archive_problem_report(report, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp movie_media, do: generate(video_media(generate(movie())))
end
