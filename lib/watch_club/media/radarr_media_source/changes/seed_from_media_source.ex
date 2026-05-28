defmodule WatchClub.Media.RadarrMediaSource.Changes.SeedFromMediaSource do
  @moduledoc """
  Copies the Radarr implementation attributes off a `MediaSource`
  passed as the `:media_source` argument onto the wizard. Runs as the
  first change on `Wizard.for_edit` so subsequent validations and
  changes (connection check, profile loading) see the seeded values.

  The argument's `:implementation` must already be loaded — the
  LiveComponent always loads it before opening the modal.
  """
  use Ash.Resource.Change

  alias WatchClub.Media.RadarrMediaSource

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :media_source) do
      %{implementation: %RadarrMediaSource{} = impl} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:base_url, impl.base_url)
        |> Ash.Changeset.force_change_attribute(:api_key, impl.api_key)
        |> Ash.Changeset.force_change_attribute(
          :selected_quality_profile_id,
          impl.quality_profile_id
        )
        |> Ash.Changeset.force_change_attribute(:selected_root_path, impl.root_folder_path)
        |> Ash.Changeset.force_change_attribute(
          :local_root_folder_path,
          impl.local_root_folder_path
        )
        |> Ash.Changeset.force_change_attribute(
          :webhook_callback_base_url,
          impl.webhook_callback_base_url
        )

      _ ->
        Ash.Changeset.add_error(
          changeset,
          "media_source must be a MediaSource with :implementation loaded"
        )
    end
  end
end
