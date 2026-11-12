defmodule WatchClub.History.HiddenFromHomeTest do
  use WatchClub.DataCase

  import WatchClub.Generator

  alias WatchClub.History
  alias WatchClub.History.HiddenFromHome

  describe "hide_from_home/*" do
    test "hides the Content from the actor's Home, on their content topic" do
      user = generate(user())
      user_id = user.id
      %{id: content_id} = generate(movie())
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:user:#{user_id}")

      History.hide_from_home!(content_id, actor: user)

      assert [%HiddenFromHome{user_id: ^user_id, content_id: ^content_id}] =
               Ash.read!(HiddenFromHome, authorize?: false)

      assert_receive %Ash.Notifier.Notification{
        resource: HiddenFromHome,
        action: %{type: :create}
      }
    end

    test "hiding it again keeps it hidden once" do
      user = generate(user())
      content = generate(movie())
      generate(hidden_from_home(user, content.id))

      History.hide_from_home!(content.id, actor: user)

      assert [_hidden] = Ash.read!(HiddenFromHome, authorize?: false)
    end
  end

  describe "show_on_home/*" do
    test "shows the Content on the actor's Home again, on their content topic" do
      user = generate(user())
      content = generate(movie())
      generate(hidden_from_home(user, content.id))
      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "content:user:#{user.id}")

      History.show_on_home!(content.id, actor: user)

      assert [] = Ash.read!(HiddenFromHome, authorize?: false)

      assert_receive %Ash.Notifier.Notification{
        resource: HiddenFromHome,
        action: %{type: :destroy}
      }
    end

    test "leaves the Content hidden from other Users' Home" do
      [user, other] = generate_many(user(), 2)
      content = generate(movie())
      generate(hidden_from_home(other, content.id))

      History.show_on_home!(content.id, actor: user)

      assert [%HiddenFromHome{}] = Ash.read!(HiddenFromHome, authorize?: false)
    end
  end
end
