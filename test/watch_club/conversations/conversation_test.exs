defmodule WatchClub.Conversations.ConversationTest do
  use WatchClub.DataCase

  import WatchClub.Conversations

  alias WatchClub.Contents.ContentIdentity
  alias WatchClub.Conversations.{Conversation, Message, Participant}

  describe "recommend_content/*" do
    test "starts a Conversation that is unread only for the recipients" do
      [recommender, friend, other_friend] = generate_many(user(), 3)
      movie = generate(movie())

      :ok = Phoenix.PubSub.subscribe(WatchClub.PubSub, "user:#{friend.id}")

      conversation =
        recommend_content!(
          ContentIdentity.from_content(movie),
          %{recipient_ids: [friend.id, other_friend.id], body: "You'll love it"},
          actor: recommender,
          load: [:recommendation, participants: [:unread_count]]
        )

      assert conversation.content_id == movie.id
      assert conversation.recommended_by_id == recommender.id

      assert %Message{kind: :recommendation, body: "You'll love it"} =
               conversation.recommendation

      assert conversation.recommendation.author_id == recommender.id

      assert conversation.participants |> Enum.map(&{&1.user_id, &1.unread_count}) |> Enum.sort() ==
               Enum.sort([{recommender.id, 0}, {friend.id, 1}, {other_friend.id, 1}])

      assert_receive %Ash.Notifier.Notification{
        resource: Participant,
        action: %{name: :create},
        data: %Participant{user_id: user_id}
      }

      assert user_id == friend.id
    end

    test "needs someone to recommend the Content to" do
      user = generate(user())
      movie = generate(movie())

      recommend_content(ContentIdentity.from_content(movie), %{recipient_ids: []}, actor: user)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Changes.InvalidAttribute{
          field: :recipient_ids,
          message: "Choose at least one person"
        } ->
          true

        _ ->
          false
      end)
    end
  end

  describe "list_conversations/*" do
    test "lists the actor's Conversations, the one with the latest Message first" do
      [user, friend, stranger] = generate_many(user(), 3)
      [movie, other_movie] = generate_many(movie(), 2)
      older = generate(conversation(user, movie, [friend]))
      newer = generate(conversation(friend, other_movie, [user]))
      generate(conversation(friend, movie, [stranger]))

      assert ids(list_conversations!(actor: user)) == [newer.id, older.id]

      generate(message(older, friend))

      assert ids(list_conversations!(actor: user)) == [older.id, newer.id]
    end

    test "keeps the Conversations about one Content" do
      [user, friend] = generate_many(user(), 2)
      [movie, other_movie] = generate_many(movie(), 2)
      about_movie = generate(conversation(user, movie, [friend]))
      generate(conversation(user, other_movie, [friend]))

      assert ids(list_conversations!(%{content_id: movie.id}, actor: user)) == [about_movie.id]
    end
  end

  describe "list_unread_conversations/*" do
    test "lists the actor's Conversations with Messages they haven't read, the latest Message first" do
      [user, friend] = generate_many(user(), 2)
      [movie, other_movie, third_movie] = generate_many(movie(), 3)
      recommended_to_user = generate(conversation(friend, movie, [user]))
      replied_to = generate(conversation(user, other_movie, [friend]))
      generate(message(replied_to, friend))
      generate(conversation(user, third_movie, [friend]))

      assert ids(list_unread_conversations!(actor: user)) ==
               [replied_to.id, recommended_to_user.id]
    end
  end

  describe "get_conversation/*" do
    test "is only for its Participants" do
      [user, friend, stranger] = generate_many(user(), 3)
      conversation = generate(conversation(user, generate(movie()), [friend]))

      assert %Conversation{} = get_conversation!(conversation.id, actor: friend)

      get_conversation(conversation.id, actor: stranger)
      |> assert_has_error(Ash.Error.Invalid, fn
        %Ash.Error.Query.NotFound{} -> true
        _ -> false
      end)
    end
  end

  defp ids(conversations), do: Enum.map(conversations, & &1.id)
end
