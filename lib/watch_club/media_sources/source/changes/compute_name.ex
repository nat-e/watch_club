defmodule WatchClub.MediaSources.Source.Changes.ComputeName do
  @moduledoc """
  Fills `:name` from the source's configuration when the caller did not
  provide one. Runs on `:create_filesystem` / `:create_radarr` /
  `:create_sonarr` after the type-specific input has been normalized and
  accepted. Users can later edit the name through the update actions.

  Fallback patterns:
    * filesystem → `"Filesystem: <path>"`
    * radarr     → `"Radarr · <root_folder_path>"`
    * sonarr     → `"Sonarr · <root_folder_path>"`
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :name) do
      name when name in [nil, ""] ->
        case fallback_name(changeset) do
          nil -> changeset
          name -> Ash.Changeset.change_attribute(changeset, :name, name)
        end

      _ ->
        changeset
    end
  end

  defp fallback_name(changeset) do
    case Ash.Changeset.get_attribute(changeset, :source_type) do
      :filesystem ->
        case Ash.Changeset.get_argument(changeset, :filesystem_path) do
          path when is_binary(path) and path != "" -> "Filesystem: #{path}"
          _ -> nil
        end

      type when type in [:radarr, :sonarr, :sportarr] ->
        case Ash.Changeset.get_argument(changeset, :root_folder_path) do
          root when is_binary(root) and root != "" ->
            "#{WatchClub.MediaSources.Servarr.Flavor.label(type)} · #{root}"

          _ ->
            nil
        end

      _ ->
        nil
    end
  end
end
