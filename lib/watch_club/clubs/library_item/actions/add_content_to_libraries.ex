defmodule WatchClub.Clubs.LibraryItem.Actions.AddContentToLibraries do
  @moduledoc """
  Adds a Content to several libraries at once for the acting user.

  This creates the Content if it does not exist yet and creates one Notification
  per library the Content is added to.
  """
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Clubs.LibraryItem
  alias WatchClub.Contents

  @impl true
  def run(input, _opts, context) do
    content_identity = input.arguments.content_identity

    with {:ok, content} <- Contents.get_or_create_content(content_identity, context.actor) do
      %Ash.BulkResult{notifications: notifications} =
        input.arguments.library_ids
        |> Enum.map(&%{content_id: content.id, library_id: &1})
        |> Ash.bulk_create!(LibraryItem, :create,
          scope: context,
          return_records?: false,
          return_notifications?: true
        )

      {:ok, content, notifications}
    end
  end
end
