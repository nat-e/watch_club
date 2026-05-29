defmodule WatchClub.Integrations.Servarr.Webhook do
  @moduledoc """
  Builds the notification config body Radarr / Sonarr expect on
  `POST /api/v3/notification` and `POST /api/v3/notification/test`. The two
  endpoints share the same body shape; only the persistence side-effect
  differs.

  The body is identical across products except for the event flags, which
  the caller supplies — the `Radarr` / `Sonarr` facades own their own flag
  lists (`onMovie*` vs `onSeries*` / `onEpisodeFile*`).
  """

  @implementation "Webhook"
  @config_contract "WebhookSettings"
  @method_post 1

  @type config :: %{
          name: String.t(),
          callback_url: String.t(),
          token: String.t()
        }

  @spec body([atom()], config()) :: map()
  def body(event_flags, %{name: name, callback_url: callback_url, token: token}) do
    flags = Map.new(event_flags, &{&1, true})

    Map.merge(flags, %{
      name: name,
      implementation: @implementation,
      configContract: @config_contract,
      includeHealthWarnings: true,
      tags: [],
      fields: [
        %{name: "url", value: callback_url},
        %{name: "method", value: @method_post},
        %{name: "username", value: ""},
        %{name: "password", value: ""},
        %{name: "headers", value: [%{key: "X-WatchClub-Token", value: token}]}
      ]
    })
  end
end
