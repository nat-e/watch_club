defmodule WatchClub.Playback.PlaybackSessionSupervisor do
  @moduledoc false

  use DynamicSupervisor

  alias WatchClub.Playback.PlaybackSessionManager

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_child(actor, playback_session_id) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {PlaybackSessionManager, %{id: playback_session_id, user_id: actor.id, actor: actor}}
    )
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
