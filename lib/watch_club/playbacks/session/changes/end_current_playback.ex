defmodule WatchClub.Playbacks.Session.Changes.EndCurrentPlayback do
  @moduledoc """
  Ends the Playback Session's current Playback, if any, once the Playback Session ended.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.Playbacks.{Playback, Session}

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, session ->
      end_current_playback!(session, context)
      {:ok, session}
    end)
  end

  @doc "Ends the Playback Session's current Playback, if any."
  def end_current_playback!(%Session{id: session_id}, context) do
    Playback
    |> Ash.Query.filter(session_id == ^session_id and is_nil(ended_at))
    |> Ash.bulk_update!(:end, %{}, strategy: :stream, scope: context)
  end
end
