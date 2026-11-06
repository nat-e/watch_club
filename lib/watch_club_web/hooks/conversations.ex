defmodule WatchClubWeb.Hooks.Conversations do
  @moduledoc """
  Subscribes every page to the topics of the current User's Conversations, and to each new one as
  it starts, so a page can show their Messages as they arrive. Keeps the Inbox tab's unread count,
  on `current_user`, up to date.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

  alias Ash.Notifier.Notification
  alias WatchClub.{Accounts, Conversations}
  alias WatchClub.Conversations.{Message, Participant}

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      [actor: socket.assigns.current_user, query: [select: [:id]]]
      |> Conversations.list_conversations!()
      |> Enum.each(&subscribe(&1.id))
    end

    {:cont, attach_hook(socket, :conversations, :handle_info, &handle_info/2)}
  end

  defp handle_info(
         %Notification{resource: Participant, action: %{name: :create}, data: participant},
         socket
       ) do
    subscribe(participant.conversation_id)
    {:cont, reload_current_user(socket)}
  end

  defp handle_info(%Notification{resource: resource}, socket)
       when resource in [Message, Participant],
       do: {:cont, reload_current_user(socket)}

  defp handle_info(_message, socket), do: {:cont, socket}

  defp subscribe(conversation_id),
    do: Phoenix.PubSub.subscribe(WatchClub.PubSub, "conversation:#{conversation_id}")

  defp reload_current_user(socket) do
    user = Accounts.get_current_user!(actor: socket.assigns.current_user)
    assign(socket, :current_user, user)
  end
end
