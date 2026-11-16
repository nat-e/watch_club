[
  import_deps: [
    :ash_state_machine,
    :ash_authentication,
    :ash_authentication_phoenix,
    :ash_phoenix,
    :ash_postgres,
    :ash,
    :reactor,
    :ecto,
    :ecto_sql,
    :phoenix
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "*.{heex,ex,exs}",
    "{config,credo,lib,test}/**/*.{heex,ex,exs}",
    "dev/catalog/manifest/*.exs"
  ]
]
