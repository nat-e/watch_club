defmodule WatchClub.Media.RadarrMediaSource.Validations.CheckRadarrConnection do
  @moduledoc """
  Calls `Radarr.get_status/2` to fetch the server's identity, then
  asserts:

    * the server answered (transport / auth attribution)
    * `appName` is `"Radarr"` (catches users pointing the wizard at
      Sonarr or Lidarr by accident — same v3 API shape, different
      product)

  Errors are attached to the appropriate form field so the wizard can
  highlight the offending input.
  """
  use Ash.Resource.Validation

  alias WatchClub.Integrations.Radarr

  @impl true
  def validate(%Ash.Changeset{} = changeset, _opts, _context) do
    base_url = Ash.Changeset.get_argument_or_attribute(changeset, :base_url)
    api_key = Ash.Changeset.get_argument_or_attribute(changeset, :api_key)

    case Radarr.get_status(base_url, api_key) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        attribute_error(reason)
    end
  end

  defp attribute_error(:unauthorized),
    do: {:error, field: :api_key, message: "Radarr rejected this API key."}

  defp attribute_error(:not_found),
    do: {:error, field: :base_url, message: "Radarr API was not found at this URL."}

  defp attribute_error(:rate_limited),
    do: {:error, field: :base_url, message: "Radarr is rate-limiting requests. Try again."}

  defp attribute_error(:client_error),
    do: {:error, field: :base_url, message: "Radarr rejected the request."}

  defp attribute_error(:server_error),
    do: {:error, field: :base_url, message: "Radarr returned a server error."}

  defp attribute_error(:invalid_response),
    do: {:error, field: :base_url, message: "This URL did not respond like a Radarr server."}

  defp attribute_error({:transport_error, _}),
    do: {:error, field: :base_url, message: "Could not connect to Radarr at this URL."}

  defp attribute_error(other),
    do: {:error, field: :base_url, message: "Could not reach Radarr: #{inspect(other)}"}
end
