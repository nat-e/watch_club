defmodule WatchClub.ActivityFeed.ContentWatchedEventTest do
  use WatchClub.DataCase

  import WatchClub.ActivityFeed

  alias WatchClub.ActivityFeed.Events.ContentWatchedEvent

  describe "add_content_watched_event/*" do
    test "groups a User's events in one Feed Entry that every User sees" do
      watcher = generate(user())
      [first, second] = for _ <- 1..2, do: generate(movie())
      add_content_watched_event!(first.id, nil, actor: watcher)
      add_content_watched_event!(second.id, nil, actor: watcher)

      assert [entry] = get_user_activity_feed!(actor: generate(user()))
      assert Enum.map(entry.events, & &1.content_id) == [second.id, first.id]
      assert Enum.all?(entry.events, &(&1.actor_id == watcher.id))
    end

    test "keeps different Users' events in separate Feed Entries" do
      [first, second] = for _ <- 1..2, do: generate(user())
      movie = generate(movie())
      add_content_watched_event!(movie.id, nil, actor: first)
      add_content_watched_event!(movie.id, nil, actor: second)

      entries = get_user_activity_feed!(actor: first)

      assert Enum.map(entries, &hd(&1.events).actor_id) == [second.id, first.id]
    end

    test "starts a new Feed Entry after 12 hours" do
      watcher = generate(user())
      first = generate(movie())
      event = add_content_watched_event!(first.id, nil, actor: watcher)
      [group, actor_id, started_at] = String.split(event.group_key, ":")
      earlier = String.to_integer(started_at) - 13 * 60 * 60

      Ash.Seed.update!(event, %{
        group_key: "#{group}:#{actor_id}:#{earlier}",
        created_at: DateTime.add(event.created_at, -13, :hour)
      })

      second = generate(movie())
      add_content_watched_event!(second.id, nil, actor: watcher)

      assert [newer, older] = get_user_activity_feed!(actor: watcher)
      assert Enum.map(newer.events, & &1.content_id) == [second.id]
      assert Enum.map(older.events, & &1.content_id) == [first.id]
    end

    test "adds a Movie or TV Show Episode once per Feed Entry" do
      watcher = generate(user())
      movie = generate(movie())
      tv_show = generate(tv_show(num_seasons: 1, episodes_per_season: 2))
      episodes = Ash.load!(tv_show, tv_show: :episodes).tv_show.episodes

      for _ <- 1..2 do
        add_content_watched_event!(movie.id, nil, actor: watcher)

        for episode <- episodes,
            do: add_content_watched_event!(tv_show.id, episode.id, actor: watcher)
      end

      assert length(Ash.read!(ContentWatchedEvent)) == 3
    end
  end
end
