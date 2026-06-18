defmodule WatchClub.Clubs.LibraryItem.Actions.RemoveContentFromLibraries do
  @moduledoc """
  Removes a Content from several libraries at once for the acting user.

  Resolves the ContentIdentity to a Content, then bulk-destroys its LibraryItems
  in the given libraries through the `:destroy` action — so each removal runs its
  membership policy. `:destroy` itself emits no notification; this action emits a
  single `content_changed` so the broadcast is deduplicated.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias WatchClub.Clubs.LibraryItem
  alias WatchClub.Contents
  alias WatchClub.Contents.Notifiers.ContentChangedNotifier

  @impl true
  def run(input, _opts, context) do
    library_ids = input.arguments.library_ids

    with {:ok, content} <-
           Contents.get_or_create_content(input.arguments.content_identity, context.actor) do
      LibraryItem
      |> Ash.Query.filter(content_id == ^content.id and library_id in ^library_ids)
      |> Ash.bulk_destroy!(:destroy, %{},
        scope: context,
        strategy: :stream,
        return_records?: false
      )

      notification =
        ContentChangedNotifier.create_notification(
          input.resource,
          input.action,
          content,
          :global,
          context.actor
        )

      {:ok, content, [notification]}
    end
  end
end
