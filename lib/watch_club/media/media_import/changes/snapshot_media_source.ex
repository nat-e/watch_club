defmodule WatchClub.Media.MediaImport.Changes.SnapshotMediaSource do
  use Ash.Resource.Change

  alias WatchClub.Media.MediaSource

  @impl true
  def change(changeset, _opts, _context) do
    media_source_id = Ash.Changeset.get_attribute(changeset, :media_source_id)

    case WatchClub.Media.get_media_source_by_id(media_source_id,
           authorize?: false,
           load: [:name]
         ) do
      {:ok, %MediaSource{} = media_source} ->
        Ash.Changeset.change_attribute(changeset, :media_source_snapshot, %{
          "id" => media_source.id,
          "name" => media_source.name,
          "source_type" => Atom.to_string(media_source.source_type),
          "media_type" => Atom.to_string(media_source.media_type),
          "filesystem_path" => media_source.filesystem_path
        })

      {:ok, nil} ->
        Ash.Changeset.add_error(changeset,
          field: :media_source_id,
          message: "does not reference an existing Media Source"
        )

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end
end
