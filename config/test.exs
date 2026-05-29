import Config
config :watch_club, token_signing_secret: "MZu4G2ZTbmfn3gr/cC0ByNzTEWMWqzIB"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true]
config :ash, :disable_async?, true
config :ash, :missed_notifications, :ignore

config :watch_club, Oban, testing: :manual

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :watch_club, WatchClub.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "watch_club_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :watch_club, WatchClubWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ybQLLsVG2eqE4I9pIAjfTe/n++rk1G3fZw/DxsIeTxkYX2lRNitqtxzMyAjqxxP1",
  server: false

config :watch_club,
  tmdb_req_options: [
    plug: {Req.Test, WatchClub.Integrations.Tmdb.Client}
  ],
  servarr_req_options: [
    plug: {WatchClub.Integrations.Servarr.TestStub, []}
  ]

config :watch_club, import_pipeline_filesystem: WatchClub.Media.ImportPipelineMock
config :watch_club, :ffprobe, WatchClub.Media.FfprobeMock

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
