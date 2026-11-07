defmodule WatchClub.ActivityFeed.FeedEntryTest do
  use WatchClub.DataCase

  import WatchClub.ActivityFeed

  alias WatchClub.ActivityFeed.Events.ContentWatchedEvent
  alias WatchClub.Contents.ContentIdentity
  alias WatchClub.History

  describe "get_user_activity_feed/*" do
    test "groups a User's watching events and shows them to every User" do
      watcher = generate(user())
      viewer = generate(user())
      movies = for _ <- 1..2, do: generate(movie())
      for movie <- movies, do: mark_watched!(movie, watcher)

      assert [entry] = get_user_activity_feed!(actor: viewer)

      assert Enum.sort(Enum.map(entry.events, & &1.content_id)) ==
               Enum.sort(Enum.map(movies, & &1.id))

      assert Enum.all?(entry.events, &(&1.actor_id == watcher.id))
      assert [^entry] = get_user_activity_feed!(actor: watcher)
    end

    test "starts a new entry after 12 hours" do
      watcher = generate(user())
      first = generate(movie())
      mark_watched!(first, watcher)
      [event] = Ash.read!(ContentWatchedEvent)
      [group, actor_id, started_at] = String.split(event.group_key, ":")
      earlier = String.to_integer(started_at) - 13 * 60 * 60

      Ash.Seed.update!(event, %{
        group_key: "#{group}:#{actor_id}:#{earlier}",
        created_at: DateTime.add(event.created_at, -13, :hour)
      })

      second = generate(movie())
      mark_watched!(second, watcher)

      assert [newer, older] = get_user_activity_feed!(actor: watcher)
      assert Enum.map(newer.events, & &1.content_id) == [second.id]
      assert Enum.map(older.events, & &1.content_id) == [first.id]
    end

    test "keeps different Users' watching events separate" do
      first = generate(user())
      second = generate(user())
      movie = generate(movie())
      mark_watched!(movie, first)
      mark_watched!(movie, second)

      assert entries = get_user_activity_feed!(actor: first)
      assert length(entries) == 2

      assert Enum.sort(for entry <- entries, event <- entry.events, do: event.actor_id) ==
               Enum.sort([first.id, second.id])
    end

    test "updates the existing event and removes it when marked unwatched" do
      watcher = generate(user())
      viewer = generate(user())
      movie = generate(movie())
      mark_watched!(movie, watcher)
      mark_watched!(movie, watcher)

      assert [%{events: [_event]}] = get_user_activity_feed!(actor: viewer)

      History.mark_content_not_watched!(ContentIdentity.from_content(movie), actor: watcher)
      Oban.drain_queue(queue: :activity_feed_event_handlers, with_scheduled: true)
      assert get_user_activity_feed!(actor: viewer) == []
    end
  end

  defp mark_watched!(movie, actor) do
    History.mark_content_watched!(ContentIdentity.from_content(movie), actor: actor)
    Oban.drain_queue(queue: :activity_feed_event_handlers, with_scheduled: true)
  end
end
