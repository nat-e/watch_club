defmodule WatchClub.Integrations.Servarr.QualityProfile do
  @moduledoc false

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t()
        }

  defstruct [:id, :name]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"]
    }
  end
end
