defmodule WatchClub.Playbacks.Session.Changes.BumpCurrentPlayback do
  @moduledoc """
  Bumps the Session's current Playback's `last_active_at` to now and forwards
  the heartbeat's reported `position_seconds` into the Playback `:update`,
  where it drives the actor's Watch Progress.
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
      |> Ash.bulk_update!(
        :update,
        %{last_active_at: DateTime.utc_now(), position_seconds: position},
        strategy: :stream,
        scope: context
      )

      {:ok, session}
    end)
  end
end
