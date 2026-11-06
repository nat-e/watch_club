defmodule WatchClub.Requests.RequestSubscriberTest do
  use WatchClub.DataCase

  import WatchClub.Generator

  alias WatchClub.Requests
  alias WatchClub.Requests.RequestSubscriber

  describe "get_notified/*" do
    test "makes the User a Request Subscriber, on their content topic" do
      user = generate(user())
      user_id = user.id
      %{id: request_id} = generate(content_request(generate(user()), generate(movie())))
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:user:#{user_id}")

      Requests.get_notified!(request_id, actor: user)

      assert [%RequestSubscriber{user_id: ^user_id, content_request_id: ^request_id}] =
               Ash.read!(RequestSubscriber, authorize?: false)

      assert_receive %Ash.Notifier.Notification{
        resource: RequestSubscriber,
        action: %{type: :create},
        data: %RequestSubscriber{user_id: ^user_id}
      }
    end

    test "doing it again keeps one Request Subscriber" do
      user = generate(user())
      request = generate(content_request(user, generate(movie())))
      generate(request_subscriber(user, request))

      Requests.get_notified!(request.id, actor: user)

      assert [%RequestSubscriber{}] = Ash.read!(RequestSubscriber, authorize?: false)
    end
  end

  describe "stop_getting_notified/*" do
    test "the User stops being a Request Subscriber, on their content topic" do
      user = generate(user())
      user_id = user.id
      request = generate(content_request(user, generate(movie())))
      generate(request_subscriber(user, request))
      %{id: other_subscriber_id} = generate(request_subscriber(generate(user()), request))
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:user:#{user_id}")

      Requests.stop_getting_notified!(request.id, actor: user)

      assert [%RequestSubscriber{id: ^other_subscriber_id}] =
               Ash.read!(RequestSubscriber, authorize?: false)

      assert_receive %Ash.Notifier.Notification{
        resource: RequestSubscriber,
        action: %{type: :destroy},
        data: %RequestSubscriber{user_id: ^user_id}
      }
    end

    test "can't stop another User's notifications" do
      request = generate(content_request(generate(user()), generate(movie())))
      %{id: subscriber_id} = generate(request_subscriber(generate(user()), request))

      Requests.stop_getting_notified(request.id, actor: generate(user()))
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Query.NotFound{} -> true
        _ -> false
      end)

      assert [%RequestSubscriber{id: ^subscriber_id}] =
               Ash.read!(RequestSubscriber, authorize?: false)
    end
  end
end
