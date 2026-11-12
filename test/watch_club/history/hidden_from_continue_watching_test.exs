defmodule WatchClub.History.HiddenFromContinueWatchingTest do
  use WatchClub.DataCase

  import WatchClub.Generator

  alias WatchClub.History
  alias WatchClub.History.HiddenFromContinueWatching

  describe "hide_from_continue_watching/*" do
    test "hides the Content from the actor's Continue Watching, on their content topic" do
      user = generate(user())
      user_id = user.id
      %{id: content_id} = generate(movie())
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:user:#{user_id}")

      History.hide_from_continue_watching!(content_id, actor: user)

      assert [%HiddenFromContinueWatching{user_id: ^user_id, content_id: ^content_id}] =
               Ash.read!(HiddenFromContinueWatching, authorize?: false)

      assert_receive %Ash.Notifier.Notification{
        resource: HiddenFromContinueWatching,
        action: %{type: :create}
      }
    end

    test "hiding it again keeps it hidden once" do
      user = generate(user())
      content = generate(movie())
      generate(hidden_from_continue_watching(user, content.id))

      History.hide_from_continue_watching!(content.id, actor: user)

      assert [_hidden] = Ash.read!(HiddenFromContinueWatching, authorize?: false)
    end
  end

  describe "unhide_from_continue_watching/*" do
    test "brings the Content back in the actor's Continue Watching, on their content topic" do
      user = generate(user())
      content = generate(movie())
      generate(hidden_from_continue_watching(user, content.id))
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:user:#{user.id}")

      History.unhide_from_continue_watching!(content.id, actor: user)

      assert [] = Ash.read!(HiddenFromContinueWatching, authorize?: false)

      assert_receive %Ash.Notifier.Notification{
        resource: HiddenFromContinueWatching,
        action: %{type: :destroy}
      }
    end

    test "leaves the Content hidden from other Users' Continue Watching" do
      [user, other] = generate_many(user(), 2)
      content = generate(movie())
      generate(hidden_from_continue_watching(other, content.id))

      History.unhide_from_continue_watching!(content.id, actor: user)

      assert [%HiddenFromContinueWatching{}] =
               Ash.read!(HiddenFromContinueWatching, authorize?: false)
    end
  end
end
