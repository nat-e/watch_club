defmodule WatchClub.Media.RadarrMediaSource.Actions.LoadRadarrProfiles do
  @moduledoc """
  Implementation for `RadarrMediaSource.load_radarr_profiles/2`.

  Hits `/api/v3/qualityprofile` and `/api/v3/rootfolder` on the target
  Radarr server in parallel. If both succeed, returns a populated
  `Radarr.Connection`. The two calls are sufficient evidence that the
  URL + API key are valid — no separate `/system/status` check is
  needed.

  Returns the first `{:error, reason}` if either call fails; the other
  task is awaited to completion so it doesn't leak.
  """
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Integrations.Radarr
  alias WatchClub.Integrations.Radarr.Connection

  @task_timeout :timer.seconds(15)

  @impl true
  def run(input, _opts, _context) do
    base_url = input.arguments.base_url
    api_key = input.arguments.api_key

    profiles_task = Task.async(fn -> Radarr.list_quality_profiles(base_url, api_key) end)
    root_folders_task = Task.async(fn -> Radarr.list_root_folders(base_url, api_key) end)

    profiles_result = Task.await(profiles_task, @task_timeout)
    root_folders_result = Task.await(root_folders_task, @task_timeout)

    case {profiles_result, root_folders_result} do
      {{:ok, profiles}, {:ok, root_folders}} ->
        {:ok,
         %Connection{
           base_url: base_url,
           api_key: api_key,
           profiles: profiles,
           root_folders: root_folders
         }}

      {{:error, reason}, _} ->
        {:error, reason}

      {_, {:error, reason}} ->
        {:error, reason}
    end
  end
end
