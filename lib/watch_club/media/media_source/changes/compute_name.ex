defmodule WatchClub.Media.MediaSource.Changes.ComputeName do
  @moduledoc """
  Fills `:name` from the source's configuration when the caller did not
  provide one. Runs on `:create_filesystem` after path normalization; the
  fallback is `"Filesystem: <path>"`. Users can later edit the name
  through `:update`.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :name) do
      name when name in [nil, ""] ->
        path = Ash.Changeset.get_attribute(changeset, :filesystem_path)
        Ash.Changeset.change_attribute(changeset, :name, "Filesystem: #{path}")

      _ ->
        changeset
    end
  end
end
