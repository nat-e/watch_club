defmodule WatchClub.MediaSources.Servarr.Flavor do
  @moduledoc """
  The Servarr product a Media Source talks to (Radarr / Sonarr), as an
  `Ash.Type.Enum`.

  The product `label/1` is also the `appName` the server reports on
  `/api/v3/system/status`. `app/1` is the module holding everything else that
  differs between products.
  """

  use Ash.Type.Enum,
    values: [
      radarr: [label: "Radarr", description: "A Radarr server (movies)"],
      sonarr: [label: "Sonarr", description: "A Sonarr server (TV shows)"]
    ]

  alias WatchClub.MediaSources.Servarr

  @doc "The module that translates this flavor's API, see `WatchClub.MediaSources.Servarr.App`."
  @spec app(t()) :: module()
  def app(:radarr), do: Servarr.Radarr
  def app(:sonarr), do: Servarr.Sonarr
end
