defmodule WatchClub.Integrations.Radarr.Connection do
  @moduledoc """
  Snapshot of what the Add Radarr Source flow learned about a Radarr
  server in one round-trip. Returned by
  `WatchClub.Media.load_radarr_profiles/2` and consumed by the
  configure-step modal.

  Carries the credentials so the LiveView doesn't have to thread them
  through hidden form inputs, plus the lists used to populate the
  quality-profile and root-folder pickers.
  """

  alias WatchClub.Integrations.Radarr.{QualityProfile, RootFolder}

  @type t :: %__MODULE__{
          base_url: String.t(),
          api_key: String.t(),
          profiles: [QualityProfile.t()],
          root_folders: [RootFolder.t()]
        }

  defstruct [:base_url, :api_key, :profiles, :root_folders]
end
