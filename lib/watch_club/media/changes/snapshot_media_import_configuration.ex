defmodule WatchClub.Media.Changes.SnapshotMediaImportConfiguration do
  use Ash.Resource.Change

  alias WatchClub.Media.MediaImportConfiguration

  @impl true
  def change(changeset, _opts, _context) do
    configuration_id = Ash.Changeset.get_attribute(changeset, :configuration_id)

    case WatchClub.Media.get_media_import_configuration_by_id(configuration_id,
           authorize?: false,
           load: [:name]
         ) do
      {:ok, %MediaImportConfiguration{} = configuration} ->
        Ash.Changeset.change_attribute(changeset, :configuration_snapshot, %{
          "id" => configuration.id,
          "name" => configuration.name,
          "source_type" => Atom.to_string(configuration.source_type),
          "content_type" => Atom.to_string(configuration.content_type),
          "media_type" => Atom.to_string(configuration.media_type),
          "filesystem_path" => configuration.filesystem_path
        })

      {:ok, nil} ->
        Ash.Changeset.add_error(changeset,
          field: :configuration_id,
          message: "does not reference an existing Media Import Configuration"
        )

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end
end
