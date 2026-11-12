defmodule WatchClub.MediaSources.Source.Changes.DeleteMedia do
  @moduledoc """
  Before a Media Source is deleted, cancels its Processing Media Import, so its jobs stop adding
  Media, then deletes its Media through their `destroy`, which removes their trickplay and audio
  fingerprints.

  Run outside a transaction, each Media's destroy commits on its own, and the deleted Media are
  notified even when a later step fails. A failure leaves the Media Source with the Media it
  still has.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.MediaCatalog
  alias WatchClub.MediaCatalog.Media
  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.Import

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      media_source_id = changeset.data.id
      opts = Ash.Context.to_opts(context)

      Import
      |> Ash.Query.filter(media_source_id == ^media_source_id and status == :processing)
      |> MediaSources.cancel_media_import!(opts)

      # One at a time: a bulk destroy keeps all its notifications in the process dictionary, which
      # the Ecto tracing copies on every query, so its time grows with the square of the Media.
      Media
      |> Ash.Query.filter(media_source_id == ^media_source_id)
      |> Ash.stream!(opts)
      |> Enum.each(&MediaCatalog.destroy_media!(&1, opts))

      changeset
    end)
  end
end
