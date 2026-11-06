defmodule WatchClub.Conversations.Message.Changes.MarkConversationReadForAuthor do
  @moduledoc """
  Marks the Conversation read for the Participant who just posted in it: their own Message is
  never unread for them.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.Conversations.Participant

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, message ->
      # Nothing matches when the actor isn't a Participant: the action's policy then forbids it
      %Ash.BulkResult{notifications: notifications} =
        Participant
        |> Ash.Query.filter(
          conversation_id == ^message.conversation_id and user_id == ^context.actor.id
        )
        |> Ash.bulk_update!(:mark_read, %{},
          authorize?: false,
          notify?: true,
          return_notifications?: true,
          return_errors?: true
        )

      {:ok, message, notifications}
    end)
  end
end
