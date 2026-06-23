defmodule WatchClub.Clubs.LibraryItem.Actions.RemoveContentFromLibraries do
  @moduledoc """
  Removes a Content from several libraries at once for the acting user.

  This creates the Content if it does not exist yet and creates one Notification
  per library the Content is removed from.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias WatchClub.Clubs.LibraryItem
  alias WatchClub.Contents

  @impl true
  def run(input, _opts, context) do
    library_ids = input.arguments.library_ids

    with {:ok, content} <-
           Contents.get_or_create_content(input.arguments.content_identity, context.actor) do
      %Ash.BulkResult{notifications: notifications} =
        LibraryItem
        |> Ash.Query.filter(content_id == ^content.id and library_id in ^library_ids)
        |> Ash.bulk_destroy!(:destroy, %{},
          scope: context,
          strategy: :stream,
          return_records?: false,
          return_notifications?: true
        )

      {:ok, content, notifications}
    end
  end
end
