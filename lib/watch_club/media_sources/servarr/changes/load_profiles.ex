defmodule WatchClub.MediaSources.Servarr.Changes.LoadProfiles do
  @moduledoc """
  Fetches quality profiles and root folders from the server and stores them
  on the wizard so the next step can render them as picker options.

  Stored as plain map lists on the in-memory wizard — no related resource
  needed. Runs right after `CheckConnection`, so it expects a server that
  answers and crashes on any error.
  """
  use Ash.Resource.Change

  alias OpentelemetryProcessPropagator.Task
  alias WatchClub.Integrations.Servarr.Client

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      base_url = Ash.Changeset.get_argument_or_attribute(changeset, :base_url)
      api_key = Ash.Changeset.get_argument_or_attribute(changeset, :api_key)

      profiles_task = Task.async(fn -> Client.list_quality_profiles(base_url, api_key) end)
      root_folders_task = Task.async(fn -> Client.list_root_folders(base_url, api_key) end)

      # Each request has its own timeout.
      {:ok, profiles} = Task.await(profiles_task, :infinity)
      {:ok, root_folders} = Task.await(root_folders_task, :infinity)

      changeset
      |> Ash.Changeset.force_change_attribute(
        :quality_profiles,
        Enum.map(profiles, &%{"id" => &1.id, "name" => &1.name})
      )
      |> Ash.Changeset.force_change_attribute(:root_folders, Enum.map(root_folders, & &1.path))
    end)
  end
end
