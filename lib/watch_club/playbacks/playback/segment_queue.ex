defmodule WatchClub.Playbacks.Playback.SegmentQueue do
  @moduledoc """
  Makes HLS segments, and makes each player's next segments before it asks for them: a player
  counts the wait for a segment as network time, and picks a lower quality.

  A segment a player asks for starts at once, unless it's cached, or being made, which the
  request then waits for. The next segments wait in a queue, first in, first out across players,
  and at most `@max_runs_ahead` of them are made at a time, so that they don't slow down the
  segments players wait for. Each request replaces the segments its group queued before, which
  drops them on a seek or a quality switch. Runs already started finish.
  """
  use GenServer

  alias OpenTelemetry.Ctx
  alias WatchClub.Playbacks.Playback.SegmentCache

  @max_runs_ahead 2

  @type job :: %{output_path: Path.t(), make: (-> {:ok, Path.t()} | {:error, term()})}

  # The coordinator and its runs restart together, so no run outlives the state tracking it.
  def child_spec(_opts) do
    children = [
      {Task.Supervisor, name: __MODULE__.TaskSupervisor},
      %{id: __MODULE__, start: {__MODULE__, :start_link, []}}
    ]

    %{
      id: __MODULE__,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_all]]}
    }
  end

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, nil, Keyword.put(opts, :name, __MODULE__))

  @doc """
  Returns the segment of `job` once it's made, and queues `next_jobs` in place of the jobs
  `group` queued before. Each run's span belongs to the trace of the request that started or
  queued it.
  """
  @spec fetch(term(), job(), [job()]) :: {:ok, Path.t()} | {:error, term()}
  def fetch(group, job, next_jobs) do
    case GenServer.call(
           __MODULE__,
           {:fetch, group, job, next_jobs, Ctx.get_current()},
           :infinity
         ) do
      {:exit, reason} -> exit(reason)
      result -> result
    end
  end

  # `queue` holds a few jobs per player, oldest first. `runs` holds the running jobs by task
  # reference, with the callers waiting for them.
  @impl true
  def init(nil), do: {:ok, %{queue: [], runs: %{}}}

  @impl true
  def handle_call({:fetch, group, job, next_jobs, context}, from, state) do
    queue =
      Enum.reject(state.queue, fn {queued_group, _job, _context} -> queued_group == group end) ++
        Enum.map(next_jobs, &{group, &1, context})

    state = %{state | queue: queue}

    state =
      cond do
        SegmentCache.cached?(job.output_path) ->
          GenServer.reply(from, {:ok, job.output_path})
          state

        ref = run_ref(state, job.output_path) ->
          update_in(state.runs[ref].callers, &[from | &1])

        true ->
          start_run(state, job, context, false, [from])
      end

    {:noreply, start_runs_ahead(state)}
  end

  @impl true
  def handle_info({ref, result}, state) do
    Process.demonitor(ref, [:flush])
    complete_run(state, ref, result)
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state),
    do: complete_run(state, ref, {:exit, reason})

  defp complete_run(state, ref, reply) do
    {run, runs} = Map.pop!(state.runs, ref)
    Enum.each(run.callers, &GenServer.reply(&1, reply))
    {:noreply, start_runs_ahead(%{state | runs: runs})}
  end

  defp start_runs_ahead(state) do
    runs_ahead = Enum.count(state.runs, fn {_ref, run} -> run.ahead? end)

    case state.queue do
      [{_group, job, context} | queue] when runs_ahead < @max_runs_ahead ->
        state = %{state | queue: queue}

        if SegmentCache.cached?(job.output_path) or run_ref(state, job.output_path),
          do: start_runs_ahead(state),
          else: state |> start_run(job, context, true, []) |> start_runs_ahead()

      _queue ->
        state
    end
  end

  # Propagator Task wrappers would only copy the GenServer's empty process-dictionary context.
  defp start_run(state, job, context, ahead?, callers) do
    task =
      Task.Supervisor.async_nolink(__MODULE__.TaskSupervisor, fn ->
        Ctx.attach(context)
        job.make.()
      end)

    put_in(state.runs[task.ref], %{output_path: job.output_path, ahead?: ahead?, callers: callers})
  end

  defp run_ref(state, output_path) do
    Enum.find_value(state.runs, fn {ref, run} -> if run.output_path == output_path, do: ref end)
  end
end
