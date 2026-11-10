import Config
config :watch_club, token_signing_secret: "MZu4G2ZTbmfn3gr/cC0ByNzTEWMWqzIB"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true]
config :ash, :disable_async?, true
config :ash, :missed_notifications, :ignore

config :watch_club, Oban, testing: :manual

# Tests prune the segment cache, so keep it apart from the dev servers' cache
config :watch_club, :segment_cache_root, Path.expand("../tmp/segment_cache", __DIR__)

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
    plug: {Req.Test, WatchClub.Integrations.Tmdb.Client},
    retry: false
  ],
  servarr_req_options: [
    plug: {WatchClub.Integrations.Servarr.TestStub, []}
  ],
  sportarr_hub_req_options: [
    plug: {Req.Test, WatchClub.Integrations.SportarrHub},
    retry: false
  ]

config :watch_club, import_scanner_filesystem: WatchClub.MediaSources.Import.ScannerMock
config :watch_club, :ffprobe, WatchClub.Ffmpeg.ProbeMock
config :watch_club, :app_data, Path.expand("../tmp/test/app_data", __DIR__)

# Servarr actions run their *arr HTTP calls in `before_transaction` hooks; under
# the test sandbox those run inside the surrounding transaction, which is fine.
config :ash, warn_on_transaction_hooks?: false

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
