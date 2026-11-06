defmodule WatchClub.Requests.ContentRequestTest do
  @moduledoc """
  Verifies the Content Request functions, the read model derived for a ContentRequest
  (`percent_imported`, `status_group`, `best_source_request`) and that it stays in sync as the
  request's dependencies change — media imported, Media Source Request created.

  Servarr (Radarr / Sonarr) is faked globally by `Servarr.TestStub`, so the
  request → submit → import flow runs with no per-test HTTP setup.
  """
  use WatchClub.DataCase

  require Ash.Query

  import WatchClub.Generator

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

  describe "list_current_user_content_requests/*" do
    test "lists the Content Requests the User is a Request Subscriber of" do
      user = generate(user())
      subscribed = generate(content_request(generate(user()), generate(movie())))
      generate(request_subscriber(user, subscribed))
      # Made by the User, who isn't one of its Request Subscribers
      generate(content_request(user, generate(movie())))

      assert [%ContentRequest{id: id}] = Requests.list_current_user_content_requests!(actor: user)
      assert id == subscribed.id
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
    test "updates movie when media is imported" do
      user = generate(user())
      movie = generate(movie())

      # Request the movie
      %ContentRequest{
        id: request_id,
        best_source_request: nil,
        percent_imported: +0.0,
        status_group: :in_progress,
        updated_at: initial_updated_at
      } =
        request =
        Requests.request_content!(ContentIdentity.from_content(movie),
          load: [:best_source_request, :percent_imported, :status_group],
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
        status_group: :completed,
        updated_at: updated_at
      } =
        Ash.reload!(request,
          load: [:best_source_request, :percent_imported, :status_group],
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
        status_group: :in_progress
      } =
        request =
        Requests.request_content!(ContentIdentity.from_content(show),
          load: [:best_source_request, :percent_imported, :status_group],
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
        status_group: :in_progress
      } =
        Ash.reload!(request,
          load: [:best_source_request, :percent_imported, :status_group],
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
        status_group: :completed
      } =
        Ash.reload!(request,
          load: [:best_source_request, :percent_imported, :status_group],
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
      %ContentRequest{id: request_id, best_source_request_id: nil, status_group: :in_progress} =
        request =
        Requests.request_content!(ContentIdentity.from_content(movie),
          load: [:status_group],
          actor: user
        )

      # The submit worker adds the movie to Radarr and creates the MSR, which the
      # global stub reads as still searching.
      Oban.drain_queue(queue: :media_source_requests)

      [%MediaSourceRequest{id: msr_id, media_source_id: ^radarr_id, status: :searching}] =
        MediaSourceRequest
        |> Ash.Query.filter(content_id == ^movie.id)
        |> Ash.read!(authorize?: false)

      # The ContentRequest now links to its MSR (searching collapses to :in_progress)
      %ContentRequest{
        best_source_request_id: ^msr_id,
        percent_imported: +0.0,
        status_group: :in_progress
      } = Ash.reload!(request, load: [:percent_imported, :status_group], actor: user)

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
        status_group: :completed
      } = Ash.reload!(request, load: [:percent_imported, :status_group], actor: user)
    end
  end
end
