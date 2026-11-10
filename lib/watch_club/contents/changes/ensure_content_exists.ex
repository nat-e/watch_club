defmodule WatchClub.Contents.Changes.EnsureContentExists do
  @moduledoc """
  Resolves the action's `:content_identity` argument into a real `Content`, creating it from the
  Metadata Provider if it does not exist yet, and sets `content_id` on the changeset. Request
  Content, Recommend Content and Add to Playlist use it, since any Content can be requested,
  recommended or added to a Playlist.

  Runs `before_transaction` so the nested `Content.create` (which fetches from the Metadata
  Provider in its own `before_transaction` hook) happens before this action's transaction opens,
  keeping the HTTP fetch out of the transaction. A failed fetch fails the action.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      content_identity = Ash.Changeset.get_argument(changeset, :content_identity)

      case Contents.get_or_refresh_content(content_identity, %{max_age: :infinity},
             scope: context
           ) do
        {:ok, content} -> Ash.Changeset.force_change_attribute(changeset, :content_id, content.id)
        # The Metadata Provider is unavailable, or has no such Content
        {:error, error} -> Ash.Changeset.add_error(changeset, error)
      end
    end)
  end
end
