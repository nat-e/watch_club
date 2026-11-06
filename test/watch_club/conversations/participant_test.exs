defmodule WatchClub.Conversations.ParticipantTest do
  use WatchClub.DataCase

  import WatchClub.Conversations

  alias WatchClub.Accounts
  alias WatchClub.Conversations.Participant

  describe "mark_conversation_read/*" do
    test "marks every Message of the Conversation read" do
      [user, friend] = generate_many(user(), 2)
      conversation = generate(conversation(friend, generate(movie()), [user]))
      generate(message(conversation, friend))

      assert Accounts.get_current_user!(actor: user).unread_conversation_count == 1

      participant = participant(conversation, user)
      assert participant.unread_count == 2

      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "user:#{user.id}")

      participant = mark_conversation_read!(participant, actor: user, load: [:unread_count])

      assert participant.unread_count == 0
      assert Accounts.get_current_user!(actor: user).unread_conversation_count == 0

      assert_receive %Ash.Notifier.Notification{
        resource: Participant,
        action: %{name: :mark_read}
      }
    end

    test "can't mark a Conversation read for someone else" do
      [user, friend] = generate_many(user(), 2)
      conversation = generate(conversation(friend, generate(movie()), [user]))

      conversation
      |> participant(user)
      |> mark_conversation_read(actor: friend)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end

  defp participant(conversation, user) do
    conversation
    |> Ash.load!([participants: [:unread_count]], authorize?: false)
    |> Map.fetch!(:participants)
    |> Enum.find(&(&1.user_id == user.id))
  end
end
