defmodule WatchClub.Requests.ContentRequest.Changes.EnsureContentExists do
  @moduledoc """
  Resolves the `:request` action's `:content` `ContentIdentity` argument into
  a real `Content`, creating it from the Metadata Provider if it does not exist
  yet, and sets `content_id` on the changeset before the upsert. Mirrors how Add
  to Library may create missing Content.

  Runs `before_action` so `content_id` is present for the
  `unique_user_content` upsert identity.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      content_identity = Ash.Changeset.get_argument(changeset, :content_identity)

      case Contents.get_or_create_content(content_identity, context.actor) do
        {:ok, content} ->
          Ash.Changeset.force_change_attribute(changeset, :content_id, content.id)

        {:error, reason} ->
          Ash.Changeset.add_error(changeset,
            field: :external_id,
            message: "could not resolve content: #{inspect(reason)}"
          )
      end
    end)
  end
end
