defmodule WatchClub.Integrations.Servarr.RootFolder do
  @moduledoc false

  @type t :: %__MODULE__{
          id: integer() | nil,
          path: String.t() | nil,
          accessible?: boolean()
        }

  defstruct [:id, :path, :accessible?, :free_space]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      id: data["id"],
      path: data["path"],
      accessible?: Map.get(data, "accessible", true)
    }
  end
end
