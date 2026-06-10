defmodule WatchClub.MediaCatalog.Changes.DeleteTrickplay do
  @moduledoc """
  After a Media destroy commits, removes the Video's trickplay directory.
  Best-effort and harmless for non-video Media — the directory simply won't
  exist.
  """

  use Ash.Resource.Change

  alias WatchClub.Ffmpeg.Trickplay

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, media} <- result do
        File.rm_rf(Trickplay.dir(media.id))
        {:ok, media}
      end
    end)
  end
end
