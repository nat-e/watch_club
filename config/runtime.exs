import Config
import Dotenvy

# config/runtime.exs runs at boot for every environment (including releases),
# after compilation. It is the single source of truth for secrets and
# deployment settings, so development and production read the same variables
# and can't drift apart.
#
# In development, copy .env.example to .env and Dotenvy loads it below. In a
# release the file is absent and the real process environment (e.g. set by
# docker-compose) is used instead — System.get_env() is listed last so it
# always wins over the .env file. Missing .env files are ignored.
source!([".env", System.get_env()])

# ## Using releases
#
# Releases default to `server: false`, so the generated bin/server sets
# PHX_SERVER=true to start the web server, while bin/migrate leaves it unset
# to boot, migrate and exit without ever opening the HTTP port.
if env!("PHX_SERVER", :boolean, false) do
  config :watch_club, WatchClubWeb.Endpoint, server: true
end

# Each worktree sets these in its .env so that it can run alongside the others.
test_database = env!("WC_TEST_DATABASE", :string, nil)

if config_env() == :test and test_database do
  config :watch_club, WatchClub.Repo, database: test_database
end

if config_env() == :dev do
  config :live_debugger, port: env!("WC_LIVE_DEBUGGER_PORT", :integer, 4007)
end

# Everything below reads from the environment and applies to dev and prod
# alike. Test configures itself in config/test.exs (sandbox DB, mocked HTTP
# clients), so it is excluded here.
if config_env() != :test do
  config :watch_club, WatchClub.Repo,
    url: env!("WC_DATABASE_URL", :string!),
    pool_size: 10

  # A single user-supplied secret seeds everything we sign/encrypt. Distinct,
  # fixed-length secrets are derived per purpose so a value used in one context
  # can't be replayed in another. The derivation is deterministic, so the same
  # WC_SECRET keeps existing sessions and tokens valid across restarts.
  wc_secret = env!("WC_SECRET", :string!)

  # SHA-512 → 128 hex chars, satisfying Plug's 64-byte minimum for secret_key_base.
  secret_key_base = :crypto.hash(:sha512, "secret_key_base:" <> wc_secret) |> Base.encode16()
  token_signing_secret = :crypto.hash(:sha256, "token_signing:" <> wc_secret) |> Base.encode16()

  port = env!("WC_PORT", :integer, 4000)

  # The public URL, which differs from the listen address behind a reverse
  # proxy. URI.new fills in 443 or 80 when the URL has no port, so Phoenix
  # never falls back to the listen port. A path is rejected because the app
  # can't run under a sub-path.
  wc_url = env!("WC_URL", :string, "http://localhost:#{port}")

  public_url =
    case URI.new(wc_url) do
      {:ok, %URI{scheme: scheme, host: host, path: path} = uri}
      when scheme in ["http", "https"] and host not in [nil, ""] and path in [nil, "/"] ->
        uri

      _ ->
        raise "WC_URL must be a full URL without a path, such as https://watch.example.com, got: #{inspect(wc_url)}"
    end

  config :watch_club, WatchClubWeb.Endpoint,
    url: [host: public_url.host, port: public_url.port, scheme: public_url.scheme],
    # Bind on all interfaces (IPv6 :: also accepts IPv4) so the container is
    # reachable; use {0, 0, 0, 0, 0, 0, 0, 1} for loopback-only access.
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base

  config :watch_club, token_signing_secret: token_signing_secret

  config :watch_club, tmdb_req_options: [auth: {:bearer, env!("WC_TMDB_API_KEY", :string!)}]

  # Writable directory for generated assets (trickplay sprite sheets, etc.).
  # Mount a volume at WC_APP_DATA so they survive container upgrades.
  config :watch_club, :app_data, env!("WC_APP_DATA", :string, "/data")

  # Configure the logger
  if env!("WC_LOG_FORMAT", :string, "text") == "json" do
    config :logger, :default_handler,
      formatter:
        LoggerJSON.Formatters.Basic.new(
          metadata: {:all_except, [:conn, :gl, :pid, :mfa, :file, :line]}
        )
  end

  config :logger, level: env!("WC_LOG_LEVEL", :string, "info") |> String.to_existing_atom()

  # Errors are only reported when WC_SENTRY_DSN is set, and logs are only sent
  # when WC_SENTRY_LOG_LEVEL is set too. Only these metadata keys are sent, so
  # crash logs don't send the whole conn.
  sentry_metadata = [:request_id, :event, :status, :error]

  config :sentry,
    dsn: env!("WC_SENTRY_DSN", :string?, nil),
    environment_name: config_env(),
    release: Application.spec(:watch_club, :vsn) |> to_string(),
    integrations: [oban: [capture_errors: true]],
    logs: [
      level: env!("WC_SENTRY_LOG_LEVEL", :existing_atom?, nil),
      metadata: sentry_metadata,
      # Reports Logger.error messages as errors, on top of crashes
      capture_log_messages: true,
      capture_metadata: sentry_metadata,
      # The Oban integration already reports failed jobs
      capture_excluded_domains: [:oban]
    ]
end
