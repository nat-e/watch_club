defmodule WatchClub.MediaSources.Servarr.Validations.CheckConnection do
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
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.Servarr.Flavor, as: Flavor

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

    cond do
      app_name == expected ->
        :ok

      is_nil(app_name) ->
        {:error,
         field: :base_url,
         message: dgettext_noop("errors", "This URL is not a %{expected} server."),
         expected: expected}

      true ->
        {:error,
         field: :base_url,
         message: dgettext_noop("errors", "This URL is a %{app_name} server, not %{expected}."),
         app_name: app_name,
         expected: expected}
    end
  end

  # The extra keys are the message's interpolation variables.
  defp attribute_error(flavor, reason) do
    {field, message} =
      case reason do
        :unauthorized ->
          {:api_key, dgettext_noop("errors", "%{name} rejected this API key.")}

        :not_found ->
          {:base_url, dgettext_noop("errors", "%{name} API was not found at this URL.")}

        :rate_limited ->
          {:base_url, dgettext_noop("errors", "%{name} is rate-limiting requests. Try again.")}

        :client_error ->
          {:base_url, dgettext_noop("errors", "%{name} rejected the request.")}

        :server_error ->
          {:base_url, dgettext_noop("errors", "%{name} returned a server error.")}

        :invalid_response ->
          {:base_url, dgettext_noop("errors", "This URL did not respond like a %{name} server.")}

        {:transport_error, _} ->
          {:base_url, dgettext_noop("errors", "Could not connect to %{name} at this URL.")}

        _other ->
          {:base_url, dgettext_noop("errors", "Could not reach %{name}: %{reason}")}
      end

    {:error, field: field, message: message, name: Flavor.label(flavor), reason: inspect(reason)}
  end
end
