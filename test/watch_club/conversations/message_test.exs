defmodule WatchClub.Conversations.MessageTest do
  use WatchClub.DataCase

  import WatchClub.Conversations

  alias WatchClub.Accounts
  alias WatchClub.Conversations.Message

  describe "post_message/*" do
    test "posts a Message that is unread only for the other Participants" do
      [user, friend] = generate_many(user(), 2)
      conversation = generate(conversation(user, generate(movie()), [friend]))

      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "conversation:#{conversation.id}")

      message = post_message!(conversation.id, %{body: "What did you think?"}, actor: user)

      assert %Message{kind: :text, body: "What did you think?"} = message
      assert message.author_id == user.id
      assert Accounts.get_current_user!(actor: user).unread_conversation_count == 0
      assert Accounts.get_current_user!(actor: friend).unread_conversation_count == 1

      assert_receive %Ash.Notifier.Notification{resource: Message, data: %Message{id: id}}
      assert id == message.id
    end

    test "is only for the Participants" do
      [user, friend, stranger] = generate_many(user(), 3)
      conversation = generate(conversation(user, generate(movie()), [friend]))

      post_message(conversation.id, %{body: "Hello"}, actor: stranger)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end

    test "needs text" do
      [user, friend] = generate_many(user(), 2)
      conversation = generate(conversation(user, generate(movie()), [friend]))

      post_message(conversation.id, %{body: " "}, actor: friend)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{field: :body, message: "Write a message"} -> true
        _ -> false
      end)
    end
  end
end
