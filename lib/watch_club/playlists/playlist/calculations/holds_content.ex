defmodule WatchClub.Playlists.Playlist.Calculations.HoldsContent do
  @moduledoc """
  Whether the Playlist holds the Content at a `ContentIdentity`. False when WatchClub doesn't have
  that Content yet.
  """
  use Ash.Resource.Calculation

  @impl true
  def expression(_opts, %{arguments: %{content_identity: identity}}) do
    expr(
      exists(
        items,
        content.external_id_source == ^identity.external_id_source and
          content.external_id == ^identity.external_id
      )
    )
  end
end
