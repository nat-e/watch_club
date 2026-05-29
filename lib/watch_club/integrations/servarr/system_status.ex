defmodule WatchClub.Integrations.Servarr.SystemStatus do
  @moduledoc false

  @type t :: %__MODULE__{
          app_name: String.t() | nil,
          instance_name: String.t() | nil,
          version: String.t() | nil
        }

  defstruct [:app_name, :instance_name, :version]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      app_name: data["appName"],
      instance_name: data["instanceName"],
      version: data["version"]
    }
  end
end
