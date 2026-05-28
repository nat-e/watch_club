defmodule WatchClub.Media.RadarrMediaSource.Changes.RegisterRadarrWebhook do
  @moduledoc """
  Synchronous webhook registration on Radarr, run as a `before_action`
  on `RadarrMediaSource`'s `:create`. The HTTP call happens inside the
  enclosing transaction — failure aborts the create. Step 3 of the Add
  Radarr Source wizard already verified Radarr→WatchClub reachability,
  so this call is expected to succeed.

  The id, base URL, api key, and webhook secret are all known on the
  changeset before insert (the id is the parent `MediaSource`'s
  primary key threaded down by `manage_relationship`), so the
  `radarr_notification_id` can be set on the changeset and persisted
  in the same INSERT.
  """
  use Ash.Resource.Change

  alias WatchClub.Integrations.Radarr
  alias WatchClub.Shared.Url

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
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
