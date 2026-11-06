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
    if connected?(socket) do
      [actor: socket.assigns.current_user, query: [select: [:id]]]
      |> Conversations.list_conversations!()
      |> Enum.each(&subscribe(&1.id))
    end

    {:cont, attach_hook(socket, :conversations, :handle_info, &subscribe_to_new_conversation/2)}
  end

  defp subscribe_to_new_conversation(
         %Notification{resource: Participant, action: %{name: :create}, data: participant},
         socket
       ) do
    subscribe(participant.conversation_id)
    {:cont, socket}
  end

  defp subscribe_to_new_conversation(_message, socket), do: {:cont, socket}

  defp subscribe(conversation_id),
    do: Phoenix.PubSub.subscribe(WatchClub.PubSub, "conversation:#{conversation_id}")
end
