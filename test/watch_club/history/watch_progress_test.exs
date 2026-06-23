defmodule WatchClub.History.WatchProgressTest do
  use WatchClub.DataCase

  alias WatchClub.Contents.{ContentIdentity, TvShowEpisode}
  alias WatchClub.History

  setup do
    tv_show = generate(tv_show())
    movie = generate(movie())
    show_identity = ContentIdentity.from_content(tv_show)
    movie_identity = ContentIdentity.from_content(movie)

    # Generate a bunch of history to make sure it doesn't interfere between users
    user1 = generate(user())
    user2 = generate(user())
    History.mark_content_watched!(show_identity, actor: user1)
    History.mark_content_not_watched!(show_identity, %{season_number: 1}, actor: user2)
    History.mark_content_watched!(movie_identity, actor: user1)

    {:ok, tv_show: tv_show, movie: movie}
  end

  describe "movies" do
    test "movie is unwatched by default", %{movie: movie} do
      user = generate(user())

      content =
        movie |> Ash.load!([movie: [:actor_progress_status, :actor_progress]], actor: user)

      assert content.movie.actor_progress_status == :not_started
    end

    test "marks an unwatched movie as watched", %{movie: movie} do
      user = generate(user())

      History.mark_content_watched!(ContentIdentity.from_content(movie), actor: user)

      content =
        movie |> Ash.load!([movie: [:actor_progress_status, :actor_progress]], actor: user)

      assert content.movie.actor_progress_status == :completed
    end

    test "is in progress when partially watched", %{movie: movie} do
      user = generate(user())

      History.record_movie_progress!(
        %{movie_id: movie.id, position_seconds: 30 * 60, duration_seconds: 100 * 60},
        actor: user
      )

      content =
        movie |> Ash.load!([movie: [:actor_progress_status, :actor_progress]], actor: user)

      assert content.movie.actor_progress_status == :in_progress
    end

    test "is completed when more than 90% is watched", %{movie: movie} do
      user = generate(user())

      History.record_movie_progress!(
        %{movie_id: movie.id, position_seconds: 95 * 60, duration_seconds: 100 * 60},
        actor: user
      )

      content =
        movie |> Ash.load!([movie: [:actor_progress_status, :actor_progress]], actor: user)

      assert content.movie.actor_progress_status == :completed
    end

    test "marks a partially watched movie as completed", %{movie: movie} do
      user = generate(user())

      History.record_movie_progress!(
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
    test "starts at S01E01 when the user has not watched anything", %{
      tv_show: tv_show
    } do
      user = generate(user())

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

    test "moves to the next episode after watching an episode", %{tv_show: tv_show} do
      user = generate(user())
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

      # Next episode should be unstarted S02E01
      assert %TvShowEpisode{season_number: 2, episode_number: 1} = next_episode
      assert next_episode.actor_progress_status == :not_started
    end

    test "continues with the current episode when it has not been watched entirely", %{
      tv_show: tv_show
    } do
      user = generate(user())
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

      History.record_episode_progress!(
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

    test "moves to the next episode when an episode has been watched more than 90%", %{
      tv_show: tv_show
    } do
      user = generate(user())
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
        History.record_episode_progress!(
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

    test "starts back at S01E01 when the user has watched the entire show", %{
      tv_show: tv_show
    } do
      user = generate(user())
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

    test "still keeps track of the next episode when re-watching an already completed show", %{
      tv_show: tv_show
    } do
      user = generate(user())
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

    test "still keeps track of the next episode when there are gaps", %{
      tv_show: tv_show
    } do
      user = generate(user())
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
end
