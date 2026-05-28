defmodule WatchClub.Media.RadarrMediaSource.Changes.RegisterRadarrWebhook do
  @moduledoc """
  Synchronous webhook registration on Radarr, run as a
  `before_transaction` hook on `RadarrMediaSource`'s `:create`. The
  HTTP call happens *outside* the DB transaction so a slow Radarr
  response doesn't hold the transaction open. A failure short-circuits
  the action before the transaction even opens.

  The id, base URL, api key, and webhook secret are all known on the
  changeset at this point (the id is the parent `MediaSource`'s
  primary key threaded down by `manage_relationship`), so the
  `radarr_notification_id` is set on the changeset and persisted in
  the same INSERT.
  """
  use Ash.Resource.Change

  alias WatchClub.Integrations.Radarr
  alias WatchClub.Shared.Url

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      with {:ok, config} <- build_config(changeset),
           base_url = Ash.Changeset.get_attribute(changeset, :base_url),
           api_key = Ash.Changeset.get_attribute(changeset, :api_key),
           {:ok, %{id: notification_id}} <- Radarr.create_webhook(base_url, api_key, config) do
        Ash.Changeset.force_change_attribute(
          changeset,
          :radarr_notification_id,
          notification_id
        )
      else
        :error ->
          Ash.Changeset.add_error(changeset, "webhook configuration missing required fields")

        {:error, reason} ->
          Ash.Changeset.add_error(
            changeset,
            "radarr webhook registration failed: #{inspect(reason)}"
          )
      end
    end)
  end

  defp build_config(changeset) do
    id = Ash.Changeset.get_attribute(changeset, :id)
    secret = Ash.Changeset.get_attribute(changeset, :webhook_secret)
    base = Ash.Changeset.get_attribute(changeset, :webhook_callback_base_url)

    if id && secret && base do
      {:ok,
       %{
         name: "WatchClub #{id}",
         callback_url: Url.webhook_callback_url(base, :radarr, id),
         token: secret
       }}
    else
      :error
    end
  end
end
