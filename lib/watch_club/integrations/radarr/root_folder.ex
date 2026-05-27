defmodule WatchClub.Integrations.Radarr.RootFolder do
  @moduledoc false

  @type t :: %__MODULE__{
          path: String.t(),
          accessible?: boolean(),
          free_space: integer() | nil
        }

  defstruct [:path, :accessible?, :free_space]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      path: data["path"],
      accessible?: Map.get(data, "accessible", true),
      free_space: data["freeSpace"]
    }
  end
end
