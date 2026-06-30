defmodule WatchClub.Integrations.Servarr.RootFolder do
  @moduledoc false

  @type t :: %__MODULE__{
          path: String.t() | nil,
          accessible?: boolean()
        }

  defstruct [:path, :accessible?, :free_space]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      path: data["path"],
      accessible?: Map.get(data, "accessible", true)
    }
  end
end
