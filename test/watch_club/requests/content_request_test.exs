defmodule WatchClub.Requests.ContentRequestTest do
  @moduledoc """
  Verifies the Content Request functions, the read model derived for a ContentRequest
  (`percent_imported`, `status`, `best_source_request`) and that it stays in sync as the
  request's dependencies change — media imported, Media Source Request created.

  Servarr (Radarr / Sonarr) is faked globally by `Servarr.TestStub`, so the
  request → submit → import flow runs with no per-test HTTP setup.
  """
  use WatchClub.DataCase

  require Ash.Query

  import WatchClub.Generator

  alias WatchClub.Accounts
  alias WatchClub.Contents.ContentIdentity
  alias WatchClub.MediaCatalog
  alias WatchClub.Requests
  alias WatchClub.Requests.{ContentRequest, MediaSourceRequest, RequestSubscriber}
  alias WatchClub.SystemActor

  describe "request_content/*" do
    test "makes the Content's only Content Request, with the User as its first Request Subscriber" do
      user = generate(user())
      movie = generate(movie())

      request =
        Requests.request_content!(ContentIdentity.from_content(movie),
          load: [:subscribers],
          actor: user
        )

      assert request.requested_by_id == user.id
      assert [%RequestSubscriber{user_id: subscriber_id}] = request.subscribers
      assert subscriber_id == user.id
    end

    test "fails when the Content already has a Content Request" do
      movie = generate(movie())
      generate(content_request(generate(user()), movie))

      Requests.request_content(ContentIdentity.from_content(movie), actor: generate(user()))
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :content_id} -> true
        _ -> false
      end)
    end
  end

  describe "list_current_user_ready_requests/*" do
    test "lists the User's playable Content Requests, the most recently playable first" do
      user = generate(user())
      [older, newer] = movies = generate_many(movie(), 2)

      for movie <- movies do
        MediaCatalog.create_or_update_video!(media_movie_input(movie.id),
          actor: SystemActor.actor()
        )

        generate(request_subscriber(user, generate(content_request(generate(user()), movie))))
      end

      # Not playable yet
      generate(request_subscriber(user, generate(content_request(user, generate(movie())))))

      # Playable, but the User isn't one of its Request Subscribers
      playable = generate(movie())

      MediaCatalog.create_or_update_video!(media_movie_input(playable.id),
        actor: SystemActor.actor()
      )

      generate(content_request(user, playable))

      assert Requests.list_current_user_ready_requests!(actor: user)
             |> Enum.map(& &1.content_id) == [newer.id, older.id]
    end
  end

  describe "list_current_user_requests_on_the_way/*" do
    test "lists the User's Content Requests that aren't playable yet, the most recently changed first" do
      user = generate(user())

      [older, newer] =
        for updated_at <- [~U[2026-01-01 00:00:00.000000Z], ~U[2026-02-01 00:00:00.000000Z]] do
          request =
            generate(content_request(generate(user()), generate(movie()), updated_at: updated_at))

          generate(request_subscriber(user, request))
          request
        end

      # Playable
      playable = generate(movie())

      MediaCatalog.create_or_update_video!(media_movie_input(playable.id),
        actor: SystemActor.actor()
      )

      generate(request_subscriber(user, generate(content_request(user, playable))))

      assert Requests.list_current_user_requests_on_the_way!(actor: user) |> Enum.map(& &1.id) ==
               [newer.id, older.id]
    end
  end

  describe "delete_content_request/*" do
    test "the Instance Administrator deletes a Content Request, for everybody" do
      admin = generate(administrator())
      %{id: request_id} = request = generate(content_request(generate(user()), generate(movie())))
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:global")

      Requests.delete_content_request!(request, actor: admin)

      assert {:error, _} = Ash.get(ContentRequest, request_id, authorize?: false)

      assert_receive %Ash.Notifier.Notification{
        resource: ContentRequest,
        action: %{type: :destroy},
        data: %ContentRequest{id: ^request_id}
      }
    end

    test "the User who made it can't delete it" do
      user = generate(user())
      request = generate(content_request(user, generate(movie())))

      Requests.delete_content_request(request, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  describe "with no requestable media source" do
    test "the first Media makes its Request Subscribers ready unseen, on their user topic" do
      user = generate(user())
      user_id = user.id
      movie = generate(movie())
      request = Requests.request_content!(ContentIdentity.from_content(movie), actor: user)
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "user:#{user_id}")

      MediaCatalog.create_or_update_video!(media_movie_input(movie.id),
        actor: SystemActor.actor()
      )

      assert_receive %Ash.Notifier.Notification{
        resource: RequestSubscriber,
        action: %{name: :mark_ready_unseen},
        data: %RequestSubscriber{user_id: ^user_id, ready_unseen?: true}
      }

      assert %{ready_unseen_for_actor?: true} =
               Ash.load!(request, :ready_unseen_for_actor?, actor: user)

      assert %{ready_unseen_request_count: 1} = Accounts.get_current_user!(actor: user)
    end

    test "a show's next episodes keep it seen" do
      user = generate(user())
      show = generate(tv_show(num_seasons: 1, episodes_per_season: 2))

      %{implementation: %{episodes: [episode1, episode2]}} =
        Ash.load!(show, [implementation: %{load: [tv_show: :episodes]}], authorize?: false)

      request = Requests.request_content!(ContentIdentity.from_content(show), actor: user)

      MediaCatalog.create_or_update_video!(media_episode_input(episode1.id),
        actor: SystemActor.actor()
      )

      Requests.mark_current_user_requests_seen!(actor: user)

      MediaCatalog.create_or_update_video!(media_episode_input(episode2.id),
        actor: SystemActor.actor()
      )

      assert %{ready_unseen_for_actor?: false} =
               Ash.load!(request, :ready_unseen_for_actor?, actor: user)
    end

    test "updates movie when media is imported" do
      user = generate(user())
      movie = generate(movie())

      # Request the movie
      %ContentRequest{
        id: request_id,
        best_source_request: nil,
        percent_imported: +0.0,
        status: :queued,
        updated_at: initial_updated_at
      } =
        request =
        Requests.request_content!(ContentIdentity.from_content(movie),
          load: [:best_source_request, :percent_imported, :status],
          actor: user
        )

      Oban.drain_queue(queue: :media_source_requests)

      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:global")

      # Import a video for the movie
      MediaCatalog.create_or_update_video!(media_movie_input(movie.id),
        actor: SystemActor.actor()
      )

      # Make sure we got a Notification that the ContentRequest was updated
      assert_receive %Ash.Notifier.Notification{
        resource: ContentRequest,
        action: %{type: :update},
        data: %ContentRequest{id: ^request_id}
      }

      # Verify that the request was updated and is now completed
      %ContentRequest{
        best_source_request: nil,
        percent_imported: 100.0,
        status: :completed,
        updated_at: updated_at
      } =
        Ash.reload!(request,
          load: [:best_source_request, :percent_imported, :status],
          actor: user
        )

      assert DateTime.after?(updated_at, initial_updated_at)
    end

    test "updates a show when an episode has been imported, partially then fully" do
      user = generate(user())
      show = generate(tv_show(num_seasons: 1, episodes_per_season: 2))

      %{implementation: %{episodes: [episode1, episode2]}} =
        Ash.load!(show, [implementation: %{load: [tv_show: :episodes]}], authorize?: false)

      # Request the show
      %ContentRequest{
        id: request_id,
        best_source_request: nil,
        percent_imported: +0.0,
        status: :queued
      } =
        request =
        Requests.request_content!(ContentIdentity.from_content(show),
          load: [:best_source_request, :percent_imported, :status],
          actor: user
        )

      Oban.drain_queue(queue: :media_source_requests)

      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:global")

      # Import the first episode
      MediaCatalog.create_or_update_video!(media_episode_input(episode1.id),
        actor: SystemActor.actor()
      )

      # Make sure we got a Notification that the ContentRequest was updated
      assert_receive %Ash.Notifier.Notification{
        resource: ContentRequest,
        action: %{type: :update},
        data: %ContentRequest{id: ^request_id}
      }

      # Verify that the request is 50% completed
      %ContentRequest{
        best_source_request: nil,
        percent_imported: 50.0,
        status: :queued
      } =
        Ash.reload!(request,
          load: [:best_source_request, :percent_imported, :status],
          actor: user
        )

      # Import the second episode
      MediaCatalog.create_or_update_video!(media_episode_input(episode2.id),
        actor: SystemActor.actor()
      )

      # Make sure we got a Notification that the ContentRequest was updated
      assert_receive %Ash.Notifier.Notification{
        resource: ContentRequest,
        action: %{type: :update},
        data: %ContentRequest{id: ^request_id}
      }

      # Verify that the request is now fully completed
      %ContentRequest{
        best_source_request: nil,
        percent_imported: 100.0,
        status: :completed
      } =
        Ash.reload!(request,
          load: [:best_source_request, :percent_imported, :status],
          actor: user
        )
    end
  end

  describe "with a media source" do
    test "links the request to its Media Source Request and completes on import" do
      user = generate(user())
      movie = generate(movie())
      radarr = generate(radarr_media_source())
      radarr_id = radarr.id

      # Request the movie — this only enqueues the submit job; no MSR exists yet
      %ContentRequest{id: request_id, best_source_request_id: nil, status: :queued} =
        request =
        Requests.request_content!(ContentIdentity.from_content(movie),
          load: [:status],
          actor: user
        )

      # The submit worker adds the movie to Radarr and creates the MSR, which the
      # global stub reads as still searching.
      Oban.drain_queue(queue: :media_source_requests)

      [%MediaSourceRequest{id: msr_id, media_source_id: ^radarr_id, status: :searching}] =
        MediaSourceRequest
        |> Ash.Query.filter(content_id == ^movie.id)
        |> Ash.read!(authorize?: false)

      # The ContentRequest now links to its MSR, still searching
      %ContentRequest{
        best_source_request_id: ^msr_id,
        percent_imported: +0.0,
        status: :queued
      } = Ash.reload!(request, load: [:percent_imported, :status], actor: user)

      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:global")

      # Importing a video completes the request
      MediaCatalog.create_or_update_video!(media_movie_input(movie.id),
        actor: SystemActor.actor()
      )

      assert_receive %Ash.Notifier.Notification{
        resource: ContentRequest,
        action: %{type: :update},
        data: %ContentRequest{id: ^request_id}
      }

      %ContentRequest{
        best_source_request_id: ^msr_id,
        percent_imported: 100.0,
        status: :completed
      } = Ash.reload!(request, load: [:percent_imported, :status], actor: user)
    end
  end
end
