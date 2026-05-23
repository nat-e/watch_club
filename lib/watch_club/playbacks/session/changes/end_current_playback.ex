defmodule WatchClub.Playbacks.Session.Changes.EndCurrentPlayback do
  @moduledoc """
  Ends the Session's current Playback (the one with `ended_at == nil`).
  No-op when the Session has no current Playback.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.Playbacks.Playback

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, session ->
      Playback
      |> Ash.Query.filter(session_id == ^session.id and is_nil(ended_at))
      |> Ash.bulk_update!(:end, %{}, strategy: :stream, scope: context)

      {:ok, session}
    end)
  end
end
