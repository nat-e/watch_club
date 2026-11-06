defmodule WatchClub.Conversations do
  @moduledoc """
  Recommend Content: a User sends a Content to other Users, which starts a Conversation between
  them, where its Participants post Messages.
  """
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.Conversations.{Conversation, Message, Participant}

  resources do
    resource Conversation do
      define :recommend_content, action: :recommend, args: [:content_identity]
      define :list_conversations, action: :latest_first
      define :get_conversation, action: :read, get_by: [:id]
    end

    resource Participant do
      define :mark_conversation_read, action: :mark_read
    end

    resource Message do
      define :post_message, action: :post, args: [:conversation_id]
      define :get_message, action: :read, get_by: [:id]
    end
  end
end
