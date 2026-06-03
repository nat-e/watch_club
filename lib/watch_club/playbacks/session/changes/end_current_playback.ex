defmodule WatchClub.Playbacks.Session.Changes.EndCurrentPlayback do
  @moduledoc """
  Ends the Session's current Playback (the one with `ended_at == nil`),
  forwarding the reported `position_seconds` so the Playback `:end` records the
  actor's Watch Progress from the final position.
  No-op when the Session has no current Playback.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.Playbacks.Playback

  @impl true
  def change(changeset, _opts, context) do
    position = Ash.Changeset.get_argument(changeset, :position_seconds)

    Ash.Changeset.after_action(changeset, fn _changeset, session ->
      Playback
      |> Ash.Query.filter(session_id == ^session.id and is_nil(ended_at))
      |> Ash.bulk_update!(:end, %{position_seconds: position}, strategy: :stream, scope: context)

      {:ok, session}
    end)
  end
end
