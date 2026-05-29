defmodule WatchClub.Media.ServarrMediaSource.Validations.CheckServarrWebhookUrl do
  @moduledoc """
  Asks the server to fire a `Test` webhook event at the URL the user
  entered. The server resolves the call synchronously and only returns 200
  if the URL responded with 2xx, so a passing validation proves
  server→Watch Club reachability.

  Runs only after `present(:webhook_callback_base_url)` has passed and the
  wizard already has `flavor`/`base_url`/`api_key` from earlier steps.
  """
  use Ash.Resource.Validation

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.Media.ServarrFlavor, as: Flavor
  alias WatchClub.Shared.Url

  @impl true
  def validate(%Ash.Changeset{} = changeset, _opts, _context) do
    flavor = Ash.Changeset.get_attribute(changeset, :flavor)
    base_url = Ash.Changeset.get_attribute(changeset, :base_url)
    api_key = Ash.Changeset.get_attribute(changeset, :api_key)
    wizard_id = Ash.Changeset.get_attribute(changeset, :id)
    callback_base = Ash.Changeset.get_argument_or_attribute(changeset, :webhook_callback_base_url)

    config = %{
      name: "WatchClub Test #{wizard_id}",
      callback_url: Url.webhook_callback_url(callback_base, flavor, wizard_id),
      token: "watchclub-test"
    }

    case Client.test_notification(base_url, api_key, config) do
      {:ok, :verified} ->
        :ok

      {:error, reason} ->
        {:error, field: :webhook_callback_base_url, message: error_message(flavor, reason)}
    end
  end

  defp error_message(flavor, reason) do
    name = Flavor.label(flavor)

    case reason do
      :not_found -> "#{name} could not reach this URL."
      :client_error -> "#{name} rejected the webhook URL."
      :server_error -> "#{name} returned a server error."
      {:transport_error, _} -> "Could not connect to #{name}."
      other -> "Webhook test failed: #{inspect(other)}"
    end
  end
end
