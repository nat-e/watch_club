defmodule WatchClub.Conversations.Conversation.Changes.StartConversation do
  @moduledoc """
  Posts the recommendation as the new Conversation's first Message, from the actor, and adds the
  actor and the recipients as its Participants. The actor has read the recommendation, the
  recipients nothing yet.
  """
  use Ash.Resource.Change

  alias WatchClub.Conversations.{Message, Participant}

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, conversation ->
      # Ash can't send notifications from inside the outer action's transaction: returning them
      # from this hook sends them once it commits
      {recommendation, message_notifications} =
        Ash.create!(
          Message,
          %{conversation_id: conversation.id, body: Ash.Changeset.get_argument(changeset, :body)},
          action: :recommendation,
          actor: context.actor,
          authorize?: false,
          return_notifications?: true
        )

      recipients =
        changeset
        |> Ash.Changeset.get_argument(:recipient_ids)
        |> Enum.map(&%{conversation_id: conversation.id, user_id: &1})

      %Ash.BulkResult{notifications: participant_notifications} =
        Ash.bulk_create!(
          [
            %{
              conversation_id: conversation.id,
              user_id: context.actor.id,
              last_read_message_id: recommendation.id
            }
            | recipients
          ],
          Participant,
          :create,
          authorize?: false,
          notify?: true,
          return_notifications?: true,
          stop_on_error?: true,
          return_errors?: true
        )

      {:ok, conversation, message_notifications ++ participant_notifications}
    end)
  end
end
