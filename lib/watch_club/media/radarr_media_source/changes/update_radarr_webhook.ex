defmodule WatchClub.Media.RadarrMediaSource.Changes.UpdateRadarrWebhook do
  @moduledoc """
  When the user edits `:webhook_callback_base_url`, PUTs the new
  callback URL onto the existing Radarr notification (same id, same
  secret, same name). Radarr re-runs its `Test` step before
  persisting, so a successful response means the new URL was
  reachable.

  Runs in `before_transaction` so a slow Radarr response doesn't hold
  the DB transaction open and so a failure short-circuits the action
  before any DB write.

  Switching to a different Radarr server (changing `:base_url` /
  `:api_key`) is intentionally not handled — the PUT will fail
  against the new server (notification id won't exist there) and the
  user is expected to delete and recreate the source instead.
  """
  use Ash.Resource.Change

  alias WatchClub.Integrations.Radarr
  alias WatchClub.Shared.Url

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :webhook_callback_base_url) do
      Ash.Changeset.before_transaction(changeset, &sync_with_radarr/1)
    else
      changeset
    end
  end

  defp sync_with_radarr(changeset) do
    record = changeset.data
    new_base_url = Ash.Changeset.get_attribute(changeset, :base_url)
    new_api_key = Ash.Changeset.get_attribute(changeset, :api_key)
    new_callback_base = Ash.Changeset.get_attribute(changeset, :webhook_callback_base_url)

    config = %{
      name: "WatchClub #{record.id}",
      callback_url: Url.webhook_callback_url(new_callback_base, :radarr, record.id),
      token: record.webhook_secret
    }

    case Radarr.update_webhook(new_base_url, new_api_key, record.radarr_notification_id, config) do
      {:ok, _} ->
        changeset

      {:error, reason} ->
        Ash.Changeset.add_error(
          changeset,
          "radarr webhook update failed: #{inspect(reason)}"
        )
    end
  end
end
