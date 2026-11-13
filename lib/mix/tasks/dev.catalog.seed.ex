defmodule Mix.Tasks.Dev.Catalog.Seed do
  @shortdoc "Seeds an empty dev database with the catalog in dev/catalog"
  @moduledoc """
  Seeds an empty dev database with the catalog in `dev/catalog`: see its README. `mix setup`
  and `mix reset` run it. The dev server must be stopped, because the seed serves the app on
  its port while Radarr and Sonarr test their webhooks.
  """
  use Mix.Task

  @requirements ["app.config"]

  @impl true
  def run(_args) do
    if Mix.env() != :dev, do: Mix.raise("mix dev.catalog.seed only seeds the dev database")
    # The seed starts the app itself, after restoring its database, unlike `mix app.start`
    Logger.configure(level: Application.fetch_env!(:logger, :level))

    endpoint = Application.fetch_env!(:watch_club, WatchClubWeb.Endpoint)
    port = endpoint[:http][:port]

    case :gen_tcp.connect(~c"localhost", port, []) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        Mix.raise("Stop the dev server on port #{port} first")

      {:error, :econnrefused} ->
        :ok
    end

    Application.put_env(
      :watch_club,
      WatchClubWeb.Endpoint,
      Keyword.merge(endpoint, server: true, watchers: [])
    )

    WatchClub.Dev.Catalog.seed!(port)
  end
end
