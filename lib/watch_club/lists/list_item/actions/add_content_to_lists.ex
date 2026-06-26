defmodule WatchClub.Lists.ListItem.Actions.AddContentToLists do
  @moduledoc """
  Adds a Content to several of the acting user's lists at once.

  This creates the Content if it does not exist yet and creates one Notification
  per list the Content is added to.
  """
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Contents
  alias WatchClub.Lists.ListItem

  @impl true
  def run(input, _opts, context) do
    content_identity = input.arguments.content_identity

    with {:ok, content} <- Contents.get_or_create_content(content_identity, context.actor) do
      %Ash.BulkResult{notifications: notifications} =
        input.arguments.list_ids
        |> Enum.map(&%{content_id: content.id, list_id: &1})
        |> Ash.bulk_create!(ListItem, :create,
          scope: context,
          return_records?: false,
          return_notifications?: true
        )

      {:ok, content, notifications}
    end
  end
end
