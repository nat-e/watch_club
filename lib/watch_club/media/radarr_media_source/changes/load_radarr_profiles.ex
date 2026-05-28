defmodule WatchClub.Media.RadarrMediaSource.Changes.LoadRadarrProfiles do
  @moduledoc """
  After a successful connection check, fetches quality profiles and
  root folders from the Radarr server and stores them on the wizard
  so the next step can render them as picker options.

  Stored as plain map lists on the in-memory wizard — no related
  resource needed.
  """
  use Ash.Resource.Change

  alias WatchClub.Integrations.Radarr

  @task_timeout :timer.seconds(15)

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      base_url = Ash.Changeset.get_argument_or_attribute(changeset, :base_url)
      api_key = Ash.Changeset.get_argument_or_attribute(changeset, :api_key)

      profiles_task = Task.async(fn -> Radarr.list_quality_profiles(base_url, api_key) end)
      root_folders_task = Task.async(fn -> Radarr.list_root_folders(base_url, api_key) end)

      profiles_result = Task.await(profiles_task, @task_timeout)
      root_folders_result = Task.await(root_folders_task, @task_timeout)

      case {profiles_result, root_folders_result} do
        {{:ok, profiles}, {:ok, root_folders}} ->
          changeset
          |> Ash.Changeset.force_change_attribute(
            :quality_profiles,
            Enum.map(profiles, &%{"id" => &1.id, "name" => &1.name})
          )
          |> Ash.Changeset.force_change_attribute(
            :root_folders,
            Enum.map(root_folders, & &1.path)
          )

        {{:error, reason}, _} ->
          Ash.Changeset.add_error(changeset, message: connection_error_message(reason))

        {_, {:error, reason}} ->
          Ash.Changeset.add_error(changeset, message: connection_error_message(reason))
      end
    end)
  end

  defp connection_error_message(:unauthorized), do: "Radarr rejected the API key."
  defp connection_error_message(:not_found), do: "Radarr API was not found at this URL."
  defp connection_error_message({:transport_error, _}), do: "Could not connect to Radarr."
  defp connection_error_message(other), do: "Could not reach Radarr: #{inspect(other)}"
end
