defmodule WatchClub.Playback.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      WatchClub.Playback.PlaybackSessionRegistry,
      WatchClub.Playback.PlaybackSessionSupervisor,
      {Task.Supervisor, name: WatchClub.Playback.TranscodeTaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
