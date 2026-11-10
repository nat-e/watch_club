defmodule WatchClub.MixProject do
  use Mix.Project

  def project do
    [
      app: :watch_club,
      version: "0.1.5",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev,
      releases: [
        watch_club: [
          # The SDKs set up their exporters when they start, so the exporter must start first.
          applications: [
            opentelemetry_exporter: :permanent,
            opentelemetry: :temporary,
            opentelemetry_experimental: :temporary
          ]
        ]
      ],
      usage_rules: usage_rules(),
      elixirc_options: elixirc_options(Mix.env()),
      hex: [cooldown: "7d"],
      # Without line numbers, moving code doesn't make the .pot files outdated.
      # A threshold of 1.0 turns off fuzzy matching: Gettext shows fuzzy guesses as real
      # translations, so new messages must stay empty until someone translates them.
      gettext: [write_reference_line_numbers: false, fuzzy_threshold: 1.0]
    ]
  end

  defp elixirc_options(:test),
    do: [
      no_warn_undefined: [WatchClub.MediaSources.Import.ScannerMock, WatchClub.Ffmpeg.ProbeMock]
    ]

  defp elixirc_options(_), do: []

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {WatchClub.Application, []},
      extra_applications: [:logger, :runtime_tools, :xmerl]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test, ci: :test]
    ]
  end

  # Prototype code is loaded on demand by the dev tools, outside Mix compilation.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:tidewave, "~> 0.9", only: [:dev]},
      {:accept_language, "~> 0.1.0"},
      {:ash, "~> 3.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_state_machine, "~> 0.2"},
      {:bandit, "~> 1.5"},
      {:bcrypt_elixir, "~> 3.0"},
      {:cachex, "~> 4.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dotenvy, "~> 1.0"},
      {:ecto_sql, "~> 3.13"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:ex_cldr, "~> 2.47"},
      {:ex_cldr_calendars, "~> 2.4"},
      {:ex_cldr_dates_times, "~> 2.25"},
      {:ex_cldr_languages, "~> 0.3"},
      {:ex_cldr_lists, "~> 2.12"},
      {:ex_cldr_numbers, "~> 2.38"},
      {:ex_cldr_units, "~> 3.20"},
      {:ex_m3u8, "~> 0.16"},
      {:finch, "~> 0.24"},
      {:gettext, "~> 1.0"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:jason, "~> 1.2"},
      {:oban, "~> 2.22"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:live_debugger, "~> 1.0.0", only: :dev},
      {:logger_json, "~> 7.0"},
      {:lucide_icons, "~> 2.0"},
      {:mox, "~> 1.2", only: :test},
      {:oban_web, "~> 2.11"},
      {:opentelemetry_exporter, "~> 1.11"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry_api_experimental, "~> 0.6.0"},
      {:opentelemetry_experimental, "~> 0.6.0"},
      {:opentelemetry_ash, "~> 0.1.4"},
      {:opentelemetry_bandit, "~> 0.3.0"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry_oban, "~> 1.2"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_process_propagator, "~> 0.3.0"},
      {:opentelemetry_req, "~> 1.0"},
      {:phoenix, "~> 1.8.5"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.9"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:phoenix_storybook, "~> 1.2"},
      {:picosat_elixir, "~> 0.2"},
      {:postgrex, ">= 0.0.0"},
      {:req, "~> 0.5"},
      {:sentry, "~> 14.0"},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:tz, "~> 0.28"},
      {:usage_rules, "~> 1.0", only: [:dev]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "deps.compile", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      reset: ["ash.tear_down --force-drop", "ash.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd npm install --prefix assets"
      ],
      "assets.build": ["compile", "tailwind watch_club", "esbuild watch_club"],
      "assets.deploy": [
        "tailwind watch_club --minify",
        "esbuild watch_club --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"],
      # Everything CI checks. Needs Postgres and the tools from mise.toml.
      ci: [
        # Order matters: anything that compiles the project again (format,
        # gettext.extract) after protocols are consolidated logs warnings that
        # fail the next `compile --warnings-as-errors`. gettext.extract
        # recompiles everything, so it runs in its own process.
        "compile --warnings-as-errors",
        "format --check-formatted",
        "deps.unlock --check-unused",
        "credo --strict",
        "cmd --shell MIX_ENV=test mix gettext.extract --check-up-to-date",
        "ash.codegen --check",
        "cmd biome ci .",
        "test --warnings-as-errors"
      ]
    ]
  end

  defp usage_rules do
    [
      file: "AGENTS.md",
      # The usage_rules package's own rules: doc search, Elixir and OTP
      usage_rules: ["usage_rules:all"],
      skills: [
        location: ".claude/skills",
        build: [
          "ash-framework": [
            description:
              "Use this skill working with Ash Framework or any of its extensions. Always consult this when making any domain changes, features or fixes.",
            usage_rules: [:ash, ~r/^ash_/]
          ],
          "phoenix-framework": [
            description:
              "Use this skill working with Phoenix Framework. Consult this when working with the web layer, controllers, views, liveviews etc.",
            usage_rules: [:phoenix, ~r/^phoenix_/]
          ]
        ]
      ]
    ]
  end
end
