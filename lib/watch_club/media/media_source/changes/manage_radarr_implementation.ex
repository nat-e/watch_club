defmodule WatchClub.Media.MediaSource.Changes.ManageRadarrImplementation do
  @moduledoc """
  Drives the `:radarr` `has_one` relationship from the radarr-specific
  arguments on `MediaSource`'s `:create_radarr` / `:update_radarr`
  actions.

  Collects `base_url`, `api_key`, `quality_profile_id`, `root_folder_path`,
  and `local_root_folder_path` from the changeset arguments, trims the
  base URL, and hands the result to `manage_relationship/4` in
  `:direct_control` mode — `:direct_control` covers both create and
  update via its default `on_no_match: :create, on_match: :update`.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    input = %{
      base_url: trim_url(Ash.Changeset.get_argument(changeset, :base_url)),
      api_key: Ash.Changeset.get_argument(changeset, :api_key),
      quality_profile_id: Ash.Changeset.get_argument(changeset, :quality_profile_id),
      root_folder_path: Ash.Changeset.get_argument(changeset, :root_folder_path),
      local_root_folder_path:
        Ash.Changeset.get_argument(changeset, :local_root_folder_path)
    }

    Ash.Changeset.manage_relationship(changeset, :radarr, input, type: :direct_control)
  end

  defp trim_url(nil), do: nil

  defp trim_url(url) when is_binary(url) do
    url
    |> String.trim()
    |> String.replace_trailing("/", "")
  end
end
