import Config
config :ash, policies: [show_policy_breakdowns?: true]
config :ash, :pub_sub, debug?: true

# Connection settings (url, pool) come from config/runtime.exs via your .env
# file. These are development-only debugging aids for the database connection.
config :watch_club, WatchClub.Repo,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# For development, we disable any cache and enable debugging and code reloading.
# The watchers run external asset bundlers; live_reload refreshes browser tabs.
config :watch_club, WatchClubWeb.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:watch_club, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:watch_club, ~w(--watch)]},
    tailwind_storybook: {Tailwind, :install_and_run, [:storybook, ~w(--watch)]}
  ],
  # Reload browser tabs when matching files change.
  live_reload: [
    web_console_logger: false,
    patterns: [
      # Static assets, except user uploads
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
      # Gettext translations
      ~r"priv/gettext/.*\.po$"E,
      ~r"lib/watch_club/.*\.ex$"E,
      ~r"lib/watch_club_web/.*\.(ex|heex)$"E
    ]
  ]

# Enable dev routes for dashboard, oban and storybook
config :watch_club, dev_routes: true

# We only include the error metadata in development
config :logger, :default_formatter,
  format: "[$level] $message $metadata\n",
  metadata: [:error]

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include debug annotations and locations in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  debug_attributes: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true
