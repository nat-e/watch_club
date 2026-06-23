defmodule WatchClub.MediaSources.Source.Changes.ManageServarrImplementation do
  @moduledoc """
  Drives the `:servarr` `has_one` relationship from the servarr-specific
  arguments on `Source`'s `:create_servarr` action.

  Reads `flavor` from the action argument. Collects connection and
  request-profile arguments, trims the base URL, and hands the result to
  `manage_relationship/4` in `:direct_control` mode — `:direct_control`
  covers both create and update via its default
  `on_no_match: :create, on_match: :update`.
  """
  use Ash.Resource.Change

  alias WatchClub.Shared.Path

  @impl true
  def change(changeset, _opts, _context) do
    flavor = Ash.Changeset.get_argument(changeset, :flavor)

    input = %{
      flavor: flavor,
      base_url: Path.normalize_base_url(Ash.Changeset.get_argument(changeset, :base_url)),
      api_key: Ash.Changeset.get_argument(changeset, :api_key),
      quality_profile_id: Ash.Changeset.get_argument(changeset, :quality_profile_id),
      quality_profile_name: Ash.Changeset.get_argument(changeset, :quality_profile_name),
      root_folder_path: Ash.Changeset.get_argument(changeset, :root_folder_path),
      local_root_folder_path: Ash.Changeset.get_argument(changeset, :local_root_folder_path)
    }

    input =
      case Ash.Changeset.get_argument(changeset, :webhook_callback_base_url) do
        nil -> input
        url -> Map.put(input, :webhook_callback_base_url, Path.normalize_base_url(url))
      end

    Ash.Changeset.manage_relationship(changeset, :servarr, input, type: :direct_control)
  end
end
