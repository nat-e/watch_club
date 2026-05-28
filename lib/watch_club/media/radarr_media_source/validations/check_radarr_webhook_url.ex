defmodule WatchClub.Media.RadarrMediaSource.Validations.CheckRadarrWebhookUrl do
  @moduledoc """
  Asks Radarr to fire a `Test` webhook event at the URL the user
  entered. Radarr resolves the call synchronously and only returns 200
  if the URL responded with 2xx, so a passing validation proves
  Radarr→Watch Club reachability.

  Runs only after `present(:webhook_callback_base_url)` has passed and
  the wizard already has `base_url`/`api_key` from earlier steps.
  """
  use Ash.Resource.Validation

  alias WatchClub.Integrations.Radarr
  alias WatchClub.Shared.Url

  @impl true
  def validate(%Ash.Changeset{} = changeset, _opts, _context) do
    base_url = Ash.Changeset.get_attribute(changeset, :base_url)
    api_key = Ash.Changeset.get_attribute(changeset, :api_key)
    wizard_id = Ash.Changeset.get_attribute(changeset, :id)
    callback_base = Ash.Changeset.get_argument_or_attribute(changeset, :webhook_callback_base_url)

    config = %{
      name: "WatchClub Test #{wizard_id}",
      callback_url: Url.webhook_callback_url(callback_base, :radarr, wizard_id),
      token: "watchclub-test"
    }

    case Radarr.test_webhook(base_url, api_key, config) do
      {:ok, :verified} ->
        :ok

      {:error, reason} ->
        {:error, field: :webhook_callback_base_url, message: error_message(reason)}
    end
  end

  defp error_message(:not_found), do: "Radarr could not reach this URL."
  defp error_message(:client_error), do: "Radarr rejected the webhook URL."
  defp error_message(:server_error), do: "Radarr returned a server error."
  defp error_message({:transport_error, _}), do: "Could not connect to Radarr."
  defp error_message(other), do: "Webhook test failed: #{inspect(other)}"
end
