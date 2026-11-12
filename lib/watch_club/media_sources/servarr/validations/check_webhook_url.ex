defmodule WatchClub.MediaSources.Servarr.Validations.CheckWebhookUrl do
  @moduledoc """
  Asks the server to fire a `Test` webhook event at the URL the user
  entered. The server resolves the call synchronously and only returns 200
  if the URL responded with 2xx, so a passing validation proves
  server→Watch Club reachability.

  Runs only once the callback URL is present and valid (`HttpUrl`), and the
  wizard already has `flavor`/`base_url`/`api_key` from earlier steps.
  """
  use Ash.Resource.Validation
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.Servarr.Flavor, as: Flavor
  alias WatchClubWeb.Helpers.Url

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

    app = Flavor.app(flavor)

    case Client.test_notification(
           base_url,
           api_key,
           app.notifications_path(),
           app.webhook_notification(config)
         ) do
      {:ok, :verified} ->
        :ok

      {:error, reason} ->
        # The extra keys are the message's interpolation variables.
        {:error,
         field: :webhook_callback_base_url,
         message: error_message(reason),
         name: Flavor.label(flavor)}
    end
  end

  defp error_message(reason) do
    case reason do
      :webhook_unreachable ->
        dgettext_noop("errors", "%{name} could not reach this URL.")

      :server_error ->
        dgettext_noop("errors", "%{name} returned a server error.")

      :connection_failed ->
        dgettext_noop("errors", "Could not connect to %{name}.")

      _other ->
        dgettext_noop(
          "errors",
          "The webhook test failed. Check that %{name} can reach this address."
        )
    end
  end
end
