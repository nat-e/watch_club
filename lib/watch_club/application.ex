defmodule WatchClub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    WatchClub.Shared.ObanLogger.attach()

    children = [
      {Cachex, [:tmdb_api_cache]},
      WatchClubWeb.Telemetry,
      WatchClub.Repo,
      {Task.Supervisor, name: WatchClub.Shared.Fs.TaskSupervisor},
      {Oban, Application.fetch_env!(:watch_club, Oban)},
      WatchClub.MediaSources.Import.OrphansCleanup,
      {Phoenix.PubSub, name: WatchClub.PubSub},
      {AshAuthentication.Supervisor, [otp_app: :watch_club]},
      # Start to serve requests, typically the last entry
      WatchClubWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WatchClub.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WatchClubWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
