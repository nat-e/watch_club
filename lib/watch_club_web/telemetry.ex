defmodule WatchClubWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  @duration_buckets [0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1, 2.5, 5, 7.5, 10]
  @database_buckets [
    0.0001,
    0.00025,
    0.0005,
    0.001,
    0.0025,
    0.005,
    0.01,
    0.025,
    0.05,
    0.1,
    0.25,
    0.5,
    1,
    2.5
  ]
  @job_buckets [0.01, 0.05, 0.1, 0.5, 1, 5, 10, 30, 60, 300, 900, 3600]

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
        unit: {:native, :second},
        reporter_options: [buckets: @duration_buckets]
      ),
      counter("phoenix.router_dispatch.exception.count", tags: [:route]),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :second},
        reporter_options: [buckets: @duration_buckets]
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route, :status],
        tag_values: &request_tags/1,
        unit: {:native, :second},
        reporter_options: [buckets: @duration_buckets]
      ),
      counter("phoenix.router_dispatch.stop.count",
        tags: [:route, :status],
        tag_values: &request_tags/1
      ),
      # Keeps long-poll fallbacks visible without tracing every poll.
      summary("phoenix.socket_connected.duration",
        tags: [:transport],
        unit: {:native, :second},
        reporter_options: [buckets: @duration_buckets]
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :second},
        reporter_options: [buckets: @duration_buckets]
      ),
      summary("phoenix.channel_handled_in.duration",
        unit: {:native, :second},
        reporter_options: [buckets: @duration_buckets]
      ),

      # Database Metrics
      summary("watch_club.repo.query.total_time",
        unit: {:native, :second},
        reporter_options: [buckets: @database_buckets],
        description: "The sum of the other measurements"
      ),
      summary("watch_club.repo.query.decode_time",
        unit: {:native, :second},
        reporter_options: [buckets: @database_buckets],
        description: "The time spent decoding the data received from the database"
      ),
      summary("watch_club.repo.query.query_time",
        unit: {:native, :second},
        reporter_options: [buckets: @database_buckets],
        description: "The time spent executing the query"
      ),
      summary("watch_club.repo.query.queue_time",
        unit: {:native, :second},
        reporter_options: [buckets: @database_buckets],
        description: "The time spent waiting for a database connection"
      ),
      summary("watch_club.repo.query.idle_time",
        unit: {:native, :second},
        reporter_options: [buckets: @database_buckets],
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # Oban Metrics
      counter("oban.job.stop.count", tags: [:queue, :worker], tag_values: &job_tags/1),
      counter("oban.job.exception.count", tags: [:queue, :worker], tag_values: &job_tags/1),
      summary("oban.job.stop.duration",
        tags: [:queue, :worker],
        tag_values: &job_tags/1,
        unit: {:native, :second},
        reporter_options: [buckets: @job_buckets]
      ),
      summary("oban.job.exception.duration",
        tags: [:queue, :worker],
        tag_values: &job_tags/1,
        unit: {:native, :second},
        reporter_options: [buckets: @job_buckets]
      ),
      summary("oban.job.stop.queue_time",
        tags: [:queue, :worker],
        tag_values: &job_tags/1,
        unit: {:native, :second},
        reporter_options: [buckets: @job_buckets]
      ),
      summary("oban.job.exception.queue_time",
        tags: [:queue, :worker],
        tag_values: &job_tags/1,
        unit: {:native, :second},
        reporter_options: [buckets: @job_buckets]
      ),

      # Content metadata: only Content Type, result and serving path are labels.
      counter("watch_club.contents.metadata_fetch.stop.count", tags: [:type, :result]),
      summary("watch_club.contents.metadata_fetch.stop.duration",
        tags: [:type, :result],
        unit: {:native, :second},
        reporter_options: [buckets: @duration_buckets]
      ),
      summary("watch_club.contents.metadata_fetch.callers",
        tags: [:type],
        reporter_options: [buckets: [1, 2, 3, 5, 10, 20, 50, 100]]
      ),
      counter("watch_club.contents.metadata_fetch.exception.count", tags: [:type]),
      counter("watch_club.contents.metadata_request.count", tags: [:served]),

      # TMDB HTTP attempts, with endpoint templates instead of individual IDs.
      counter("watch_club.tmdb.request.stop.count", tags: [:endpoint, :status]),
      summary("watch_club.tmdb.request.stop.duration",
        tags: [:endpoint, :status],
        unit: {:native, :second},
        reporter_options: [buckets: @duration_buckets]
      ),
      counter("watch_club.media_import.match.count", tags: [:result]),

      # Which Markers detection finds, and where from. Fingerprints: cache use and decoding time.
      counter("watch_club.marker_detection.marker.count", tags: [:media_type, :kind, :source]),
      counter("watch_club.audio_fingerprint.fetch.count", tags: [:cached]),
      summary("watch_club.audio_fingerprint.compute.stop.duration",
        tags: [:part],
        unit: {:native, :second},
        reporter_options: [buckets: @job_buckets]
      ),

      # Casting: from the Player handing the TV its token to the TV leaving, and why Playback
      # Sessions end. See docs/chromecast.md.
      counter("watch_club.cast.count", tags: [:result]),
      counter("watch_club.playback_session.end.count", tags: [:reason]),

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
