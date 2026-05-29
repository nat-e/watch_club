defmodule WatchClub.Integrations.Servarr.Webhook.RenamedFile do
  @moduledoc """
  A renamed file in a Radarr/Sonarr `Rename` webhook — its previous absolute
  path and its new path relative to the content folder. Shared shape across
  Radarr's `renamedMovieFiles` and Sonarr's `renamedEpisodeFiles`.
  """

  @type t :: %__MODULE__{previous_path: String.t() | nil, relative_path: String.t() | nil}

  defstruct [:previous_path, :relative_path]

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      previous_path: data["previousPath"],
      relative_path: data["relativePath"]
    }
  end
end
