defmodule WatchClub.Playback.PlaybackSessionRegistry do
  @moduledoc false

  def child_spec(_opts) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  def via(user_id, playback_session_id) do
    {:via, Registry, {__MODULE__, playback_session_id, user_id}}
  end

  def lookup(user_id, playback_session_id) do
    case Registry.lookup(__MODULE__, playback_session_id) do
      [{pid, ^user_id}] -> {:ok, pid}
      [{_pid, _other_user_id}] -> {:error, :not_found}
      [] -> {:error, :not_found}
    end
  end

  def session_running?(playback_session_id) do
    Registry.lookup(__MODULE__, playback_session_id) != []
  end
end
