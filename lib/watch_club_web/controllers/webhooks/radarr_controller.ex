defmodule WatchClubWeb.Webhooks.RadarrController do
  @moduledoc """
  Receiver for Radarr webhooks. Radarr POSTs every event (including
  `Test`) to the URL stored on its notification config, so this one
  handler covers wizard verification, admin "Test" clicks, and live
  events.

  In this slice only `Test` events are meaningfully handled — they
  return 200 immediately so Radarr's synchronous test round-trip
  succeeds. Every other event is authenticated against the
  `RadarrMediaSource`'s `webhook_secret`, logged, and acknowledged
  with 200. Per-event handling lives in a follow-up PR.
  """
  use WatchClubWeb, :controller

  require Logger

  alias WatchClub.Media
  alias WatchClub.SystemActor

  @token_header "x-watchclub-token"

  def handle(conn, %{"eventType" => "Test"} = _params) do
    json(conn, %{ok: true})
  end

  def handle(conn, %{"eventType" => event_type, "media_source_id" => media_source_id} = params) do
    with {:ok, source} <- load_source(media_source_id),
         :ok <- check_token(conn, source) do
      Logger.info(
        "radarr webhook",
        event_type: event_type,
        media_source_id: media_source_id,
        payload: drop_path_params(params)
      )

      json(conn, %{ok: true})
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{ok: false})
    end
  end

  def handle(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{ok: false, error: "missing eventType"})
  end

  defp load_source(media_source_id) do
    case Media.get_media_source_by_id(media_source_id,
           load: [:implementation],
           actor: SystemActor.actor()
         ) do
      {:ok, %{source_type: :radarr, implementation: implementation}}
      when not is_nil(implementation) ->
        {:ok, implementation}

      _ ->
        :error
    end
  end

  defp check_token(conn, %{webhook_secret: secret}) do
    case get_req_header(conn, @token_header) do
      [provided] ->
        if Plug.Crypto.secure_compare(provided, secret), do: :ok, else: :error

      _ ->
        :error
    end
  end

  defp drop_path_params(params), do: Map.drop(params, ["media_source_id"])
end
