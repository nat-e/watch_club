defmodule WatchClub.MediaSources.Source.Changes.CancelMediaImport do
  @moduledoc """
  Before a Media Source is deleted, cancels its Processing Media Import, so its jobs stop
  instead of importing files into a Media Source that no longer exists.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.Import

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      media_source_id = changeset.data.id

      Import
      |> Ash.Query.filter(media_source_id == ^media_source_id and status == :processing)
      |> MediaSources.cancel_media_import!(Ash.Context.to_opts(context))

      changeset
    end)
  end
end
