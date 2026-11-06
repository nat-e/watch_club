defmodule WatchClub.Conversations.MessageKind do
  @moduledoc """
  What a Message is: the recommendation that starts its Conversation, or text a Participant posts.
  """
  use Ash.Type.Enum,
    values: [
      recommendation: [description: "The recommendation that starts the Conversation"],
      text: [description: "Text a Participant posts"]
    ]
end
