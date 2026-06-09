defmodule WatchClub.Clubs.LibraryItem.Actions.AddContentToLibraries do
  @moduledoc """
  Adds a Content to several libraries at once for the acting user.

  Resolves the ContentIdentity to a Content (creating it from the Metadata
  Provider if needed), then bulk-creates a LibraryItem per library through the
  `:create` action — so each row runs its membership policy. `:create` itself
  emits no notification; this action emits a single `content_changed` so the
  broadcast is deduplicated.
  """
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Clubs.LibraryItem
  alias WatchClub.Contents
  alias WatchClub.Contents.Notifiers.ContentChangedNotifier

  @impl true
  def run(input, _opts, context) do
    content_identity = input.arguments.content_identity

    with {:ok, content} <- Contents.get_or_create_content(content_identity, context.actor) do
      input.arguments.library_ids
      |> Enum.map(fn library_id ->
        %{content_id: content.id, library_id: library_id}
      end)
      |> Ash.bulk_create!(LibraryItem, :create, scope: context, return_records?: false)

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
