defmodule WatchClubWeb.Webhooks.ServarrController do
  @moduledoc """
  Controller that handles the webhook notifications from Servarr apps.

  Checks the source's token, then hands the payload to
  `WatchClub.MediaSources.handle_servarr_webhook/3`.
  """
  use WatchClubWeb, :controller

  require Logger

  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.Servarr
  alias WatchClub.SystemActor

  @token_header "x-watchclub-token"

  # MovieAdded is useless since we got the response anyway, and it creates
  # warnings since it's received before the request is persisted in DB most of the time
  @ignored_event_types ["MovieAdded", "HealthRestored", "Health", "Test"]

  def handle(conn, %{"eventType" => event_type}) when event_type in @ignored_event_types do
    Logger.info("Servarr webhook event ignored: #{event_type}",
      event: :servarr_webhook_ignored,
      event_type: event_type
    )

    json(conn, %{ok: true})
  end

  def handle(conn, %{"eventType" => event_type, "media_source_id" => id} = params) do
    Logger.metadata(
      event_type: event_type,
      media_source_id: id
    )

    Logger.info("Servarr webhook received: #{event_type}", event: :servarr_webhook_received)

    with {:ok, source} <- fetch_source(id),
         :ok <- verify_token(conn, source) do
      MediaSources.handle_servarr_webhook!(source, params, actor: SystemActor.actor())

      json(conn, %{ok: true})
    else
      _ -> conn |> put_status(:unauthorized) |> json(%{ok: false})
    end
  end

  def handle(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{ok: false, error: "missing eventType"})
  end

  defp fetch_source(media_source_id) do
    case MediaSources.get_media_source_by_id(media_source_id,
           load: [:implementation],
           actor: SystemActor.actor()
         ) do
      {:ok, %{implementation: %Servarr{} = source}} ->
        {:ok, source}

      _ ->
        Logger.warning("Media source not found: #{media_source_id}",
          event: :servarr_webhook_media_source_not_found
        )

        :error
    end
  end

  defp verify_token(conn, %Servarr{webhook_secret: secret}) do
    with [provided] <- get_req_header(conn, @token_header),
         true <- Plug.Crypto.secure_compare(provided, secret) do
      :ok
    else
      _ ->
        Logger.warning("Invalid Servarr webhook token", event: :servarr_webhook_invalid_token)
        :error
    end
  end
end
