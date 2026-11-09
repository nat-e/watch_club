defmodule WatchClubWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children =
      if Application.fetch_env!(:watch_club, :opentelemetry)[:metrics] do
        [{WatchClub.Telemetry.Metrics, metrics()}]
      else
        []
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      counter("phoenix.endpoint.stop.count"),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      counter("phoenix.router_dispatch.exception.count", tags: [:route]),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route, :status],
        tag_values: &request_tags/1,
        unit: {:native, :millisecond}
      ),
      counter("phoenix.router_dispatch.stop.count",
        tags: [:route, :status],
        tag_values: &request_tags/1
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("watch_club.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("watch_club.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("watch_club.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("watch_club.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("watch_club.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # Oban Metrics
      counter("oban.job.stop.count", tags: [:queue, :worker], tag_values: &job_tags/1),
      counter("oban.job.exception.count", tags: [:queue, :worker], tag_values: &job_tags/1),
      summary("oban.job.stop.duration",
        tags: [:queue, :worker],
        tag_values: &job_tags/1,
        unit: {:native, :millisecond}
      ),
      summary("oban.job.exception.duration",
        tags: [:queue, :worker],
        tag_values: &job_tags/1,
        unit: {:native, :millisecond}
      ),
      summary("oban.job.stop.queue_time",
        tags: [:queue, :worker],
        tag_values: &job_tags/1,
        unit: {:native, :millisecond}
      ),
      summary("oban.job.exception.queue_time",
        tags: [:queue, :worker],
        tag_values: &job_tags/1,
        unit: {:native, :millisecond}
      ),

      # Content metadata: only Content Type, result and serving path are labels.
      counter("watch_club.contents.metadata_fetch.stop.count", tags: [:type, :result]),
      summary("watch_club.contents.metadata_fetch.stop.duration",
        tags: [:type, :result],
        unit: {:native, :millisecond}
      ),
      summary("watch_club.contents.metadata_fetch.stop.callers", tags: [:type]),
      counter("watch_club.contents.metadata_fetch.exception.count", tags: [:type]),
      counter("watch_club.contents.metadata_request.count", tags: [:served]),

      # The dependency's default poller emits these VM measurements.
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io")
    ]
  end

  defp job_tags(%{job: job}), do: Map.take(job, [:queue, :worker])

  defp request_tags(%{conn: conn} = metadata),
    do: %{route: metadata[:route], status: conn.status}
end
