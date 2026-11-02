defmodule WatchClub.Playbacks.PlaybackTest do
  use WatchClub.DataCase, async: true

  alias WatchClub.Playbacks
  alias WatchClub.SystemActor

  describe "end_inactive_playbacks/*" do
    test "ends the Playbacks without a heartbeat for two hours" do
      now = DateTime.utc_now()
      quiet = generate(playback(last_active_at: DateTime.add(now, -3, :hour)))
      active = generate(playback(last_active_at: DateTime.add(now, -1, :hour)))

      already_ended =
        generate(
          playback(
            last_active_at: DateTime.add(now, -5, :hour),
            ended_at: DateTime.add(now, -4, :hour)
          )
        )

      Playbacks.end_inactive_playbacks!(actor: SystemActor.actor())

      refute is_nil(Ash.reload!(quiet, actor: SystemActor.actor()).ended_at)
      assert is_nil(Ash.reload!(active, actor: SystemActor.actor()).ended_at)

      assert Ash.reload!(already_ended, actor: SystemActor.actor()).ended_at ==
               already_ended.ended_at
    end

    test "forbids Users" do
      user = generate(user())

      Playbacks.end_inactive_playbacks(actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
