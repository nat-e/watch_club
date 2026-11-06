defmodule WatchClubWeb.Hooks.Conversations do
  @moduledoc """
  Subscribes every page to the topics of the current User's Conversations, and to each new one as
  it starts, so a page can show their Messages as they arrive.
  """
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

  alias Ash.Notifier.Notification
  alias WatchClub.Conversations
  alias WatchClub.Conversations.Participant

  def on_mount(:default, _params, _session, socket) do
    conversations =
      if connected?(socket),
        do:
          Conversations.list_conversations!(
            actor: socket.assigns.current_user,
            query: [select: [:id]]
          ),
        else: []

    {:cont,
     socket
     |> WatchClub.PubSub.subscribe_if_connected(Enum.map(conversations, &topic(&1.id)))
     |> attach_hook(:conversations, :handle_info, &subscribe_to_new_conversation/2)}
  end

  defp subscribe_to_new_conversation(
         %Notification{resource: Participant, action: %{name: :create}, data: participant},
         socket
       ),
       do:
         {:cont,
          WatchClub.PubSub.subscribe_if_connected(socket, topic(participant.conversation_id))}

  defp subscribe_to_new_conversation(_message, socket), do: {:cont, socket}

  defp topic(conversation_id), do: "conversation:#{conversation_id}"
end
