defmodule WatchClub.History.WatchProgressTest do
  use WatchClub.DataCase

  require Ash.Query

  alias WatchClub.ActivityFeed.Events.ContentWatchedEvent
  alias WatchClub.Contents.{ContentIdentity, TvShowEpisode}
  alias WatchClub.History
  alias WatchClub.History.Watcher

  describe "movies" do
    test "movie is unwatched by default" do
      user = generate(user())

      tv_show = generate(tv_show(num_seasons: 2, episodes_per_season: 3))
      movie = generate(movie())
      show_identity = ContentIdentity.from_content(tv_show)
      movie_identity = ContentIdentity.from_content(movie)

      # Generate a bunch of history to make sure it doesn't interfere between users
      user1 = generate(user())
      user2 = generate(user())
      History.mark_content_watched!(show_identity, actor: user1)
      History.mark_content_not_watched!(show_identity, %{season_number: 1}, actor: user2)
      History.mark_content_watched!(movie_identity, actor: user1)

      content =
        movie |> Ash.load!([movie: [:actor_progress_status, :actor_progress]], actor: user)

      assert content.movie.actor_progress_status == :not_started
    end

    test "marks an unwatched movie as watched" do
      user = generate(user())
      movie = generate(movie())

      History.mark_content_watched!(ContentIdentity.from_content(movie), actor: user)

      content =
        movie |> Ash.load!([movie: [:actor_progress_status, :actor_progress]], actor: user)

      assert content.movie.actor_progress_status == :completed
    end

    test "is in progress when partially watched" do
      user = generate(user())
      movie = generate(movie())

      History.record_watch_progress!(
        %{movie_id: movie.id, position_seconds: 30 * 60, duration_seconds: 100 * 60},
        actor: user
      )

      content =
        movie |> Ash.load!([movie: [:actor_progress_status, :actor_progress]], actor: user)

      assert content.movie.actor_progress_status == :in_progress
    end

    test "is completed when more than 90% is watched" do
      user = generate(user())
      movie = generate(movie())

      History.record_watch_progress!(
        %{movie_id: movie.id, position_seconds: 95 * 60, duration_seconds: 100 * 60},
        actor: user
      )

      content =
        movie |> Ash.load!([movie: [:actor_progress_status, :actor_progress]], actor: user)

      assert content.movie.actor_progress_status == :completed
    end

    test "marks a partially watched movie as completed" do
      user = generate(user())
      movie = generate(movie())

      History.record_watch_progress!(
        %{movie_id: movie.id, position_seconds: 30 * 60, duration_seconds: 100 * 60},
        actor: user
      )

      History.mark_content_watched!(ContentIdentity.from_content(movie), actor: user)

      content =
        movie |> Ash.load!([movie: [:actor_progress_status, :actor_progress]], actor: user)

      assert content.movie.actor_progress_status == :completed
    end
  end

  describe "TV shows" do
    test "starts at S01E01 when the user has not watched anything" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 2, episodes_per_season: 3))

      content =
        tv_show
        |> Ash.load!(
          [
            tv_show: [
              :actor_progress_status,
              :actor_last_watched_at,
              actor_next_episode: [:actor_progress_status, :actor_progress]
            ]
          ],
          actor: user
        )

      next_episode = content.tv_show.actor_next_episode

      # Show is not started
      assert content.tv_show.actor_progress_status == :not_started
      assert content.tv_show.actor_last_watched_at == nil

      # Next episode should be unstarted S01E01
      assert %TvShowEpisode{season_number: 1, episode_number: 1} = next_episode
      assert next_episode.actor_progress_status == :not_started
    end

    test "moves to the next episode after watching an episode" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 2, episodes_per_season: 3))
      before = DateTime.utc_now()

      # Mark S01 watched
      History.mark_content_watched!(
        ContentIdentity.from_content(tv_show),
        %{season_number: 1},
        actor: user
      )

      content =
        tv_show
        |> Ash.load!(
          [
            tv_show: [
              :actor_progress_status,
              :actor_percent_watched,
              :actor_last_watched_at,
              actor_next_episode: [:actor_progress_status, :actor_progress]
            ]
          ],
          actor: user
        )

      next_episode = content.tv_show.actor_next_episode

      # Show is in progress, half watched
      assert content.tv_show.actor_progress_status == :in_progress
      assert content.tv_show.actor_percent_watched == 50.0
      assert DateTime.after?(content.tv_show.actor_last_watched_at, before)

      # Next episode should be unstarted S02E01
      assert %TvShowEpisode{season_number: 2, episode_number: 1} = next_episode
      assert next_episode.actor_progress_status == :not_started
    end

    test "finishes the show once every aired episode is watched" do
      user = generate(user())

      # Season 1 has aired, season 2 hasn't
      tv_show =
        generate(
          tv_show(
            num_seasons: 2,
            episodes_per_season: 3,
            start_date: Date.shift(Date.utc_today(), year: -2)
          )
        )

      History.mark_content_watched!(ContentIdentity.from_content(tv_show), actor: user)

      content =
        tv_show
        |> Ash.load!(
          [
            tv_show: [
              :actor_progress_status,
              :actor_percent_watched,
              actor_next_episode: [:actor_progress_status],
              episodes: [:actor_progress_status]
            ]
          ],
          actor: user
        )

      assert content.tv_show.actor_progress_status == :completed
      assert content.tv_show.actor_percent_watched == 100.0

      # Only the aired episodes are marked
      assert content.tv_show.episodes
             |> Enum.filter(&(&1.actor_progress_status == :completed))
             |> Enum.map(&{&1.season_number, &1.episode_number})
             |> Enum.sort() == [{1, 1}, {1, 2}, {1, 3}]

      # Next episode starts the show again instead of going to the unaired S02E01
      assert %TvShowEpisode{season_number: 1, episode_number: 1} =
               content.tv_show.actor_next_episode
    end

    test "continues with the current episode when it has not been watched entirely" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 2, episodes_per_season: 3))
      content = tv_show |> Ash.load!([tv_show: [:episodes]], actor: user)
      before = DateTime.utc_now()

      # Mark S01E01 watched
      History.mark_content_watched!(
        ContentIdentity.from_content(tv_show),
        %{season_number: 1, episode_number: 1},
        actor: user
      )

      # Start watching S01E02
      s01e02 =
        Enum.find(content.tv_show.episodes, &(&1.season_number == 1 and &1.episode_number == 2))

      History.record_watch_progress!(
        %{
          tv_show_episode_id: s01e02.id,
          position_seconds: 10 * 60,
          duration_seconds: 20 * 60
        },
        actor: user
      )

      content =
        tv_show
        |> Ash.load!(
          [
            tv_show: [
              :actor_progress_status,
              :actor_last_watched_at,
              actor_next_episode: [:actor_progress_status, :actor_progress]
            ]
          ],
          actor: user
        )

      next_episode = content.tv_show.actor_next_episode

      # Show is in progress
      assert content.tv_show.actor_progress_status == :in_progress
      assert DateTime.after?(content.tv_show.actor_last_watched_at, before)

      # Next episode should be S01E02, in progress
      assert %TvShowEpisode{season_number: 1, episode_number: 2} = next_episode
      assert next_episode.actor_progress_status == :in_progress
    end

    test "moves to the next episode when an episode has been watched more than 90%" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 2, episodes_per_season: 3))
      content = tv_show |> Ash.load!([tv_show: [:episodes]], actor: user)
      before = DateTime.utc_now()

      # Mark S01E01 watched
      History.mark_content_watched!(
        ContentIdentity.from_content(tv_show),
        %{season_number: 1, episode_number: 1},
        actor: user
      )

      # Watch 95% S01E02
      s01e02 =
        Enum.find(content.tv_show.episodes, &(&1.season_number == 1 and &1.episode_number == 2))

      s01e02_progress =
        History.record_watch_progress!(
          %{
            tv_show_episode_id: s01e02.id,
            position_seconds: 20 * 60 * 0.95,
            duration_seconds: 20 * 60
          },
          load: [:completed, :percent_watched],
          actor: user
        )

      assert s01e02_progress.completed
      assert s01e02_progress.percent_watched == 100.0

      content =
        tv_show
        |> Ash.load!(
          [
            tv_show: [
              :actor_progress_status,
              :actor_last_watched_at,
              actor_next_episode: [:actor_progress_status, :actor_progress]
            ]
          ],
          actor: user
        )

      next_episode = content.tv_show.actor_next_episode

      # Show is in progress
      assert content.tv_show.actor_progress_status == :in_progress
      assert DateTime.after?(content.tv_show.actor_last_watched_at, before)

      # Next episode should be S01E03, unstarted
      assert %TvShowEpisode{season_number: 1, episode_number: 3} = next_episode
      assert next_episode.actor_progress_status == :not_started
    end

    test "starts back at S01E01 when the user has watched the entire show" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 2, episodes_per_season: 3))
      before = DateTime.utc_now()

      # Mark the entire show watched
      History.mark_content_watched!(
        ContentIdentity.from_content(tv_show),
        %{},
        actor: user
      )

      content =
        tv_show
        |> Ash.load!(
          [
            tv_show: [
              :actor_progress_status,
              :actor_last_watched_at,
              actor_next_episode: [:actor_progress_status, :actor_progress]
            ]
          ],
          actor: user
        )

      next_episode = content.tv_show.actor_next_episode

      # Show is completed
      assert content.tv_show.actor_progress_status == :completed
      assert DateTime.after?(content.tv_show.actor_last_watched_at, before)

      # Next episode should be completed S01E01
      assert %TvShowEpisode{season_number: 1, episode_number: 1} = next_episode
      assert next_episode.actor_progress_status == :completed
    end

    test "still keeps track of the next episode when re-watching an already completed show" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 2, episodes_per_season: 3))
      before = DateTime.utc_now()

      # Mark the entire show watched
      History.mark_content_watched!(
        ContentIdentity.from_content(tv_show),
        %{},
        actor: user
      )

      # Rewatch season 1
      History.mark_content_watched!(
        ContentIdentity.from_content(tv_show),
        %{season_number: 1, episode_number: 1},
        actor: user
      )

      content =
        tv_show
        |> Ash.load!(
          [
            tv_show: [
              :actor_progress_status,
              :actor_last_watched_at,
              actor_next_episode: [:actor_progress_status, :actor_progress]
            ]
          ],
          actor: user
        )

      next_episode = content.tv_show.actor_next_episode

      # Show is completed
      assert content.tv_show.actor_progress_status == :completed
      assert DateTime.after?(content.tv_show.actor_last_watched_at, before)

      # Next episode should be completed S01E02
      assert %TvShowEpisode{season_number: 1, episode_number: 2} = next_episode
      assert next_episode.actor_progress_status == :completed
    end

    test "still keeps track of the next episode when there are gaps" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 2, episodes_per_season: 3))
      before = DateTime.utc_now()

      # Mark S02E01 watched, without watching season 1
      History.mark_content_watched!(
        ContentIdentity.from_content(tv_show),
        %{season_number: 2, episode_number: 1},
        actor: user
      )

      content =
        tv_show
        |> Ash.load!(
          [
            tv_show: [
              :actor_progress_status,
              :actor_last_watched_at,
              actor_next_episode: [:actor_progress_status, :actor_progress]
            ]
          ],
          actor: user
        )

      next_episode = content.tv_show.actor_next_episode

      # Show is in progress
      assert content.tv_show.actor_progress_status == :in_progress
      assert DateTime.after?(content.tv_show.actor_last_watched_at, before)

      # Next episode should be unstarted S02E02
      assert %TvShowEpisode{season_number: 2, episode_number: 2} = next_episode
      assert next_episode.actor_progress_status == :not_started
    end
  end

  describe "list_watchers/*" do
    test "lists who else watched a movie or is watching it, the latest first" do
      [watched, watching, actor] = generate_many(user(), 3)
      movie = generate(movie())
      identity = ContentIdentity.from_content(movie)

      History.mark_content_watched!(identity, actor: watched)

      History.record_watch_progress!(
        %{movie_id: movie.id, position_seconds: 30 * 60, duration_seconds: 100 * 60},
        actor: watching
      )

      History.mark_content_watched!(identity, actor: actor)

      assert [%Watcher{status: :in_progress} = first, %Watcher{status: :completed} = second] =
               History.list_watchers!(identity, actor: actor)

      assert first.user.id == watching.id
      assert second.user.id == watched.id
    end

    test "has watched a TV show once every aired episode is watched" do
      [watched, watching, actor] = generate_many(user(), 3)

      # Season 1 has aired, season 2 hasn't
      tv_show =
        generate(
          tv_show(
            num_seasons: 2,
            episodes_per_season: 2,
            start_date: Date.shift(Date.utc_today(), year: -2)
          )
        )

      identity = ContentIdentity.from_content(tv_show)

      History.mark_content_watched!(identity, %{season_number: 1, episode_number: 1},
        actor: watching
      )

      History.mark_content_watched!(identity, %{season_number: 1}, actor: watched)

      assert [%Watcher{status: :completed} = first, %Watcher{status: :in_progress} = second] =
               History.list_watchers!(identity, actor: actor)

      assert first.user.id == watched.id
      assert second.user.id == watching.id
    end

    test "is empty for a Content WatchClub doesn't have" do
      assert [] = History.list_watchers!(ContentIdentity.for_movie(42), actor: generate(user()))
    end
  end

  describe "content_watched events" do
    test "creates a content_watched event when the user starts watching a movie" do
      user = generate(user())
      movie = generate(movie())

      History.record_watch_progress!(
        %{movie_id: movie.id, position_seconds: 10 * 60, duration_seconds: 100 * 60},
        actor: user
      )

      event = content_watched_event(movie.id, user)

      refute event.completed
      # Movies have no episode concept, so completed_episodes is nil rather than []
      assert is_nil(event.completed_episodes)
    end

    test "creates a completed content_watched event when the user marks a movie as watched" do
      user = generate(user())
      movie = generate(movie())

      History.mark_content_watched!(ContentIdentity.from_content(movie), actor: user)

      assert content_watched_event(movie.id, user).completed
    end

    test "sets content_watched event as completed when the user finishes watching a movie" do
      user = generate(user())
      movie = generate(movie())

      History.record_watch_progress!(
        %{movie_id: movie.id, position_seconds: 95 * 60, duration_seconds: 100 * 60},
        actor: user
      )

      assert content_watched_event(movie.id, user).completed
    end

    test "deletes content_watched event when the user marks a movie has not watched" do
      user = generate(user())
      movie = generate(movie())

      History.mark_content_watched!(ContentIdentity.from_content(movie), actor: user)
      History.mark_content_not_watched!(ContentIdentity.from_content(movie), actor: user)

      refute content_watched_event(movie.id, user)
    end

    test "creates a content_watched event when the user starts watching an episode of a tv show" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 1, episodes_per_season: 2))

      s01e01 =
        tv_show
        |> Ash.load!([tv_show: [:episodes]], actor: user)
        |> then(& &1.tv_show.episodes)
        |> Enum.find(&(&1.season_number == 1 and &1.episode_number == 1))

      History.record_watch_progress!(
        %{tv_show_episode_id: s01e01.id, position_seconds: 5 * 60, duration_seconds: 20 * 60},
        actor: user
      )

      event = content_watched_event(tv_show.id, user)

      refute event.completed
      assert event.completed_episodes == []
    end

    test "creates a completed content_watched event when the user marks the show as watched" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 1, episodes_per_season: 2))

      History.mark_content_watched!(ContentIdentity.from_content(tv_show), actor: user)

      event = content_watched_event(tv_show.id, user)

      assert event.completed
      assert completed_episode_tuples(event) == [{1, 1}, {1, 2}]
    end

    test "adds an episode to the completed_episodes list when the user marks an episode as watched" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 1, episodes_per_season: 2))

      History.mark_content_watched!(
        ContentIdentity.from_content(tv_show),
        %{season_number: 1, episode_number: 1},
        actor: user
      )

      event = content_watched_event(tv_show.id, user)

      refute event.completed
      assert completed_episode_tuples(event) == [{1, 1}]
    end

    test "removes an episode to the completed_episodes list when the user marks an episode as not watched" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 1, episodes_per_season: 2))

      History.mark_content_watched!(ContentIdentity.from_content(tv_show), actor: user)

      History.mark_content_not_watched!(
        ContentIdentity.from_content(tv_show),
        %{season_number: 1, episode_number: 2},
        actor: user
      )

      event = content_watched_event(tv_show.id, user)

      refute event.completed
      assert completed_episode_tuples(event) == [{1, 1}]
    end

    test "deletes content_watched event when the user marks the show as unwatched (or the last watched episode)" do
      user = generate(user())
      tv_show = generate(tv_show(num_seasons: 1, episodes_per_season: 2))

      History.mark_content_watched!(
        ContentIdentity.from_content(tv_show),
        %{season_number: 1, episode_number: 1},
        actor: user
      )

      History.mark_content_not_watched!(
        ContentIdentity.from_content(tv_show),
        %{season_number: 1, episode_number: 1},
        actor: user
      )

      refute content_watched_event(tv_show.id, user)
    end
  end

  # Reads back the derived ContentWatchedEvent for a (user, content), or nil if there is none.
  defp content_watched_event(content_id, user) do
    Oban.drain_queue(queue: :activity_feed_event_handlers, with_scheduled: true)

    ContentWatchedEvent
    |> Ash.Query.filter(actor_id == ^user.id and content_id == ^content_id)
    |> Ash.Query.load(:scopes)
    |> Ash.read_one!(authorize?: false)
  end

  # completed_episodes as a sorted list of {season_number, episode_number} (keys may be JSONB strings)
  defp completed_episode_tuples(event) do
    event.completed_episodes
    |> Enum.map(fn ep ->
      {ep["season_number"] || ep[:season_number], ep["episode_number"] || ep[:episode_number]}
    end)
    |> Enum.sort()
  end
end
