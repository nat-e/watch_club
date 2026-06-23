defmodule WatchClub.MediaSources.Servarr.Changes.RegisterWebhook do
  @moduledoc """
  Synchronous webhook registration on the Servarr server, run as a
  `before_transaction` hook on `Servarr`'s `:create`. The HTTP
  call happens *outside* the DB transaction so a slow server response
  doesn't hold the transaction open. A failure short-circuits the action
  before the transaction even opens.

  The id, base URL, api key, flavor, and webhook secret are all known on
  the changeset at this point (the id is the parent `Source`'s primary
  key threaded down by `manage_relationship`), so the `notification_id` is
  set on the changeset and persisted in the same INSERT.
  """
  use Ash.Resource.Change

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.Servarr.Flavor
  alias WatchClubWeb.Helpers.Url

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      flavor = Ash.Changeset.get_attribute(changeset, :flavor)
      event_flags = Flavor.webhook_event_flags(flavor)

      with {:ok, config} <- build_config(changeset, flavor),
           base_url = Ash.Changeset.get_attribute(changeset, :base_url),
           api_key = Ash.Changeset.get_attribute(changeset, :api_key),
           {:ok, %{id: notification_id}} <-
             Client.create_notification(base_url, api_key, event_flags, config) do
        Ash.Changeset.force_change_attribute(changeset, :notification_id, notification_id)
      else
        :error ->
          Ash.Changeset.add_error(changeset, "webhook configuration missing required fields")

        {:error, reason} ->
          Ash.Changeset.add_error(
            changeset,
            "#{flavor} webhook registration failed: #{inspect(reason)}"
          )
      end
    end)
  end

  defp build_config(changeset, flavor) do
    id = Ash.Changeset.get_attribute(changeset, :id)
    secret = Ash.Changeset.get_attribute(changeset, :webhook_secret)
    base = Ash.Changeset.get_attribute(changeset, :webhook_callback_base_url)

    if id && secret && base do
      {:ok,
       %{
         name: "WatchClub #{id}",
         callback_url: Url.webhook_callback_url(base, flavor, id),
         token: secret
       }}
    else
      :error
    end
  end
end
