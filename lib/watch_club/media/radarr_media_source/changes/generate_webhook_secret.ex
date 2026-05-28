defmodule WatchClub.Media.RadarrMediaSource.Changes.GenerateWebhookSecret do
  @moduledoc """
  Sets `:webhook_secret` to a freshly generated 32-byte URL-safe base64
  string. Runs only on create; the secret is never editable afterwards.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.force_change_attribute(
      changeset,
      :webhook_secret,
      :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    )
  end
end
