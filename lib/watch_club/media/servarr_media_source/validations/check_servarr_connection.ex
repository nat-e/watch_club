defmodule WatchClub.Media.ServarrMediaSource.Validations.CheckServarrConnection do
  @moduledoc """
  Calls the flavor's `get_status/2` to fetch the server's identity, then
  asserts:

    * the server answered (transport / auth attribution)
    * `appName` matches the wizard's `flavor` (catches users pointing a
      Sonarr wizard at a Radarr server, or vice versa — same v3 API shape,
      different product)

  Errors are attached to the appropriate form field so the wizard can
  highlight the offending input.
  """
  use Ash.Resource.Validation

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.Media.ServarrFlavor, as: Flavor

  @impl true
  def validate(%Ash.Changeset{} = changeset, _opts, _context) do
    flavor = Ash.Changeset.get_attribute(changeset, :flavor)
    base_url = Ash.Changeset.get_argument_or_attribute(changeset, :base_url)
    api_key = Ash.Changeset.get_argument_or_attribute(changeset, :api_key)

    # `system/status` is flavor-agnostic; `flavor` is only used to assert
    # the returned `appName` is the product the user expects.
    case Client.get_status(base_url, api_key) do
      {:ok, %{app_name: app_name}} ->
        check_app_name(app_name, flavor)

      {:error, reason} ->
        attribute_error(flavor, reason)
    end
  end

  defp check_app_name(app_name, flavor) do
    expected = Flavor.label(flavor)

    if app_name == expected do
      :ok
    else
      {:error,
       field: :base_url,
       message: "This URL is a #{app_name || "different"} server, not #{expected}."}
    end
  end

  defp attribute_error(flavor, reason) do
    name = Flavor.label(flavor)

    case reason do
      :unauthorized ->
        {:error, field: :api_key, message: "#{name} rejected this API key."}

      :not_found ->
        {:error, field: :base_url, message: "#{name} API was not found at this URL."}

      :rate_limited ->
        {:error, field: :base_url, message: "#{name} is rate-limiting requests. Try again."}

      :client_error ->
        {:error, field: :base_url, message: "#{name} rejected the request."}

      :server_error ->
        {:error, field: :base_url, message: "#{name} returned a server error."}

      :invalid_response ->
        {:error, field: :base_url, message: "This URL did not respond like a #{name} server."}

      {:transport_error, _} ->
        {:error, field: :base_url, message: "Could not connect to #{name} at this URL."}

      other ->
        {:error, field: :base_url, message: "Could not reach #{name}: #{inspect(other)}"}
    end
  end
end
