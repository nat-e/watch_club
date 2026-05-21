defmodule WatchClub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  @compile {:no_warn_undefined, {AshOban, :config, 3}}

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WatchClubWeb.Telemetry,
      WatchClub.Repo,
      {Oban,
       AshOban.config(
         Application.fetch_env!(:watch_club, :ash_domains),
         Application.fetch_env!(:watch_club, Oban),
         []
       )},
      {DNSCluster, query: Application.get_env(:watch_club, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WatchClub.PubSub},
      {AshAuthentication.Supervisor, [otp_app: :watch_club]},
      WatchClub.Playback.Supervisor,
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
