defmodule WatchClub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WatchClubWeb.Telemetry,
      WatchClub.Repo,
      {DNSCluster, query: Application.get_env(:watch_club, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WatchClub.PubSub},
      # Start a worker by calling: WatchClub.Worker.start_link(arg)
      # {WatchClub.Worker, arg},
      # Start to serve requests, typically the last entry
      WatchClubWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :watch_club]}
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
