defmodule WatchClub.ActivityFeed.FeedEntryTest do
  use WatchClub.DataCase

  import WatchClub.ActivityFeed

  alias WatchClub.ActivityFeed.Events.{ContentAddedEvent, ContentWatchedEvent}
  alias WatchClub.ActivityFeed.FeedEventScope
  alias WatchClub.{Clubs, History}
  alias WatchClub.Contents.ContentIdentity

  setup do
    admin = generate(administrator())
    club = generate(club(actor: admin))
    member = generate(user())
    generate(membership(club, member))
    library = generate(library(club))

    {:ok, admin: admin, club: club, member: member, library: library}
  end

  describe "get_user_activity_feed/*" do
    test "groups what a member does in a club within 12 hours into one entry", %{
      admin: admin,
      member: member,
      library: library
    } do
      first = add_movie!(library, member)
      second = add_movie!(library, member)

      assert [added | _club_news] = get_user_activity_feed!(actor: admin)
      assert added_content_ids(added) == [second.id, first.id]
    end

    test "starts a new entry 12 hours after the first event of the latest one", %{
      admin: admin,
      member: member,
      library: library
    } do
      first = add_movie!(library, member)
      start_entries_13_hours_earlier!()
      second = add_movie!(library, member)

      assert [newer, older | _club_news] = get_user_activity_feed!(actor: admin)
      assert added_content_ids(newer) == [second.id]
      assert added_content_ids(older) == [first.id]
    end

    test "shows the watcher each of their watched events once, in one entry", %{
      member: member,
      library: library
    } do
      # The watcher sees each event through their own scope and the club's
      movies = for _ <- 1..2, do: add_movie!(library, member)
      for movie <- movies, do: mark_watched!(movie, member)

      assert [watched | _club_news] = get_user_activity_feed!(actor: member)

      assert Enum.sort(watched_content_ids(watched)) ==
               movies |> Enum.map(& &1.id) |> Enum.sort()
    end

    test "hides the entries of clubs the user is not a member of", %{
      member: member,
      library: library
    } do
      add_movie!(library, member)
      outsider = generate(user())

      assert get_user_activity_feed!(actor: outsider) == []
    end
  end

  defp add_movie!(library, actor) do
    movie = generate(movie())

    Clubs.add_content_to_libraries!(ContentIdentity.from_content(movie), [library.id],
      actor: actor
    )

    movie
  end

  defp mark_watched!(movie, actor) do
    History.mark_content_watched!(ContentIdentity.from_content(movie), actor: actor)
    Oban.drain_queue(queue: :activity_feed_event_handlers, with_scheduled: true)
  end

  defp watched_content_ids(entry) do
    for %FeedEventScope{event: %ContentWatchedEvent{} = event} <- entry.scopes,
        do: event.content_id
  end

  defp added_content_ids(entry) do
    for %FeedEventScope{event: %ContentAddedEvent{} = event} <- entry.scopes,
        do: event.library_item.content_id
  end

  defp start_entries_13_hours_earlier! do
    for scope <- Ash.read!(FeedEventScope, authorize?: false) do
      [started_at | group] = scope.group_key |> String.split(":") |> Enum.reverse()
      earlier = String.to_integer(started_at) - 13 * 60 * 60
      key = [Integer.to_string(earlier) | group] |> Enum.reverse() |> Enum.join(":")
      Ash.Seed.update!(scope, %{group_key: key})
    end
  end
end
