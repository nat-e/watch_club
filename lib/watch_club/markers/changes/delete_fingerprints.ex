defmodule WatchClub.Markers.Changes.DeleteFingerprints do
  @moduledoc """
  After a Media destroy commits, removes its Video's cached audio fingerprints.
  Harmless for non-video Media: the directory simply won't exist.
  """

  use Ash.Resource.Change

  alias WatchClub.Markers.AudioFingerprint

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, media} <- result do
        AudioFingerprint.delete!(media.id)
        {:ok, media}
      end
    end)
  end
end
