defmodule WatchClub.MediaCatalog.Changes.DeleteVideoFiles do
  @moduledoc """
  After a Media destroy commits, removes the files WatchClub made from its
  Video: the trickplay directory and the audio fingerprints. Harmless for
  non-video Media — the directories simply won't exist.
  """

  use Ash.Resource.Change

  alias WatchClub.Ffmpeg.{AudioFingerprint, Trickplay}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, media} <- result do
        File.rm_rf(Trickplay.dir(media.id))
        AudioFingerprint.delete!(media.id)
        {:ok, media}
      end
    end)
  end
end
