defmodule WatchClub.Contents.Changes.EnsureContentExists do
  @moduledoc """
  Resolves the action's `:content_identity` argument into a real `Content`, creating it from the
  Metadata Provider if it does not exist yet, and sets `content_id` on the changeset. Request
  Content and Recommend Content use it, since any Content can be requested or recommended.

  Runs `before_transaction` so the nested `Content.create` (which fetches from the Metadata
  Provider in its own `before_transaction` hook) happens before this action's transaction opens,
  keeping the HTTP fetch out of the transaction.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      content_identity = Ash.Changeset.get_argument(changeset, :content_identity)
      content = Contents.get_or_create_content!(content_identity, context.actor)

      Ash.Changeset.force_change_attribute(changeset, :content_id, content.id)
    end)
  end
end
