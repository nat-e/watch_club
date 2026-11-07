# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ash,
  allow_forbidden_field_for_relationships_by_default: true,
  default_string_length_count: :codepoints,
  infer_generic_action_reactors?: false,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: true],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true,
  redact_sensitive_values_in_errors?: true

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :authentication,
        :token,
        :user_identity,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [section_order: [:resources, :policies, :authorization, :domain, :execution]]
  ]

config :watch_club,
  ecto_repos: [WatchClub.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [
    WatchClub.Accounts,
    WatchClub.ActivityFeed,
    WatchClub.Contents,
    WatchClub.Conversations,
    WatchClub.History,
    WatchClub.Instance,
    WatchClub.MediaCatalog,
    WatchClub.MediaSources,
    WatchClub.Playbacks,
    WatchClub.Playlists,
    WatchClub.Requests
  ]

# Ash generates large SQL (many lateral joins for calcs/aggregates), which trips
# Postgres' jit_above_cost threshold. JIT compilation then dominates runtime
# (~640ms compile vs ~2ms execution) on our modest row counts, so disable it.
config :watch_club, WatchClub.Repo, parameters: [jit: "off"]

config :watch_club, Oban,
  engine: Oban.Engines.Basic,
  repo: WatchClub.Repo,
  cron: [crontab: [{"*/15 * * * *", WatchClub.Playbacks.Workers.PruneSegmentCache}]],
  # Deletes jobs older than a week to avoid Oban table from growing indefinitely
  pruner: [max_age: {7, :days}],
  # Retries jobs left in `executing` by a crash or a deploy
  lifeline: [rescue_after: {2, :hours}],
  queues: [
    activity_feed_event_handlers: 5,
    media_source_scans: 1,
    media_candidate_ingestions: 3,
    media_import_monitors: 5,
    playback_cache_maintenance: 1,
    media_source_webhooks: 1,
    # Low concurrency: submissions add+search on the *arr instance, so keep
    # the load (and indexer pressure) gentle even on a big fan-out/backfill.
    media_source_requests: 2,
    # Single worker so trickplay's full-decode ffmpeg pass never crowds out
    # imports.
    trickplay_generation: 1
  ]

# Configure the endpoint
config :watch_club, WatchClubWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: WatchClubWeb.ErrorHTML, json: WatchClubWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: WatchClub.PubSub,
  live_view: [signing_salt: "cGeO1dtg"]

# Configure esbuild (the version is required)
config :esbuild,
  # renovate: datasource=npm depName=esbuild
  version: "0.28.2",
  watch_club: [
    args:
      ~w(js/app.js js/storybook.js js/player_vidstack.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  # renovate: datasource=github-releases depName=tailwindcss packageName=tailwindlabs/tailwindcss extractVersion=^v(?<version>.+)$
  version: "4.3.3",
  watch_club: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ],
  storybook: [
    args: ~w(
      --input=assets/css/storybook.css
      --output=priv/static/assets/css/storybook.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ash, :default_belongs_to_type, :uuid_v7

# Times show in each User's time zone, which the browser sends
config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
