defmodule WatchClub.Integrations.Radarr.Webhook do
  @moduledoc """
  Helpers for the Radarr notification webhook config payload.

  Builds the body Radarr expects on `POST /api/v3/notification` and
  `POST /api/v3/notification/test`. The two endpoints share the same
  body shape; only the persistence side-effect differs.
  """

  @implementation "Webhook"
  @config_contract "WebhookSettings"
  @method_post 1

  @event_flags [
    :onGrab,
    :onDownload,
    :onUpgrade,
    :onRename,
    :onMovieAdded,
    :onMovieDelete,
    :onMovieFileDelete,
    :onMovieFileDeleteForUpgrade,
    :onHealthIssue,
    :onHealthRestored,
    :onApplicationUpdate,
    :onManualInteractionRequired
  ]

  @type config :: %{
          name: String.t(),
          callback_url: String.t(),
          token: String.t()
        }

  @spec body(config()) :: map()
  def body(%{name: name, callback_url: callback_url, token: token}) do
    flags = Map.new(@event_flags, &{&1, true})

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
