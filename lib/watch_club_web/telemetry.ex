defmodule WatchClubWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics
  import Ecto.Query, only: [from: 2]

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
        [
          {WatchClub.Telemetry.Metrics, metrics()},
          {:telemetry_poller,
           measurements: [{__MODULE__, :measure_job_queues, []}], period: :timer.seconds(5)}
        ]
      else
        []
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    database = WatchClub.Repo.config()[:database]

    List.flatten([
      # HTTP requests the router handles
      span_summary("http.server.request.duration", [:phoenix, :router_dispatch],
        tags: [
          :"http.request.method",
          :"url.scheme",
          :"http.route",
          :"http.response.status_code",
          :"error.type"
        ],
        tag_values: &http_server_tags/1,
        reporter_options: [buckets: @duration_buckets]
      ),

      # Mount and handle_params run for the HTTP render, then again when the socket connects.
      span_summary("phoenix.live_view.mount.duration", [:phoenix, :live_view, :mount],
        tags: [:"phoenix.live_view.module", :"phoenix.live_view.connected", :"error.type"],
        tag_values: &live_view_tags/1,
        reporter_options: [buckets: @duration_buckets]
      ),
      span_summary(
        "phoenix.live_view.handle_params.duration",
        [:phoenix, :live_view, :handle_params],
        tags: [:"phoenix.live_view.module", :"phoenix.live_view.connected", :"error.type"],
        tag_values: &live_view_tags/1,
        reporter_options: [buckets: @duration_buckets]
      ),
      span_summary(
        "phoenix.live_view.handle_event.duration",
        [:phoenix, :live_view, :handle_event],
        tags: [:"phoenix.live_view.module", :"phoenix.live_view.event", :"error.type"],
        tag_values: &live_view_tags/1,
        reporter_options: [buckets: @duration_buckets]
      ),
      span_summary(
        "phoenix.live_component.handle_event.duration",
        [:phoenix, :live_component, :handle_event],
        tags: [:"phoenix.live_component.module", :"phoenix.live_component.event", :"error.type"],
        tag_values:
          &%{
            "phoenix.live_component.module": inspect(&1.component),
            "phoenix.live_component.event": event_name(&1),
            "error.type": exception_type(&1)
          },
        reporter_options: [buckets: @duration_buckets]
      ),

      # Keeps long-poll fallbacks visible without tracing every poll.
      summary("phoenix.socket.connect.duration",
        event_name: [:phoenix, :socket_connected],
        unit: {:native, :second},
        tags: [:"phoenix.socket.transport"],
        tag_values: &%{"phoenix.socket.transport": &1.transport},
        reporter_options: [buckets: @duration_buckets]
      ),
      sum("phoenix.socket.drained_connections",
        event_name: [:phoenix, :socket_drain],
        measurement: :count,
        unit: :"{connection}"
      ),

      # Database
      summary("db.client.operation.duration",
        event_name: [:watch_club, :repo, :query],
        measurement: :total_time,
        unit: {:native, :second},
        tags: [
          :"db.system.name",
          :"db.namespace",
          :"db.collection.name",
          :"db.operation.name",
          :"db.response.status_code",
          :"error.type"
        ],
        tag_values: &database_tags(&1, database),
        reporter_options: [buckets: @database_buckets]
      ),
      summary("db.client.connection.wait_time",
        event_name: [:watch_club, :repo, :query],
        measurement: :queue_time,
        unit: {:native, :second},
        tags: [:"db.client.connection.pool.name"],
        tag_values: &%{"db.client.connection.pool.name": inspect(&1.repo)},
        reporter_options: [buckets: @database_buckets]
      ),

      # Oban jobs, with the attributes of their trace spans
      span_summary("messaging.process.duration", [:oban, :job],
        tags: [
          :"messaging.system",
          :"messaging.operation.name",
          :"messaging.destination.name",
          :"oban.job.worker",
          :"error.type"
        ],
        tag_values: &job_tags/1,
        reporter_options: [buckets: @job_buckets]
      ),
      span_summary("oban.job.queue_time", [:oban, :job],
        tags: [:"messaging.destination.name", :"oban.job.worker"],
        tag_values: &job_tags/1,
        reporter_options: [buckets: @job_buckets]
      ),
      # The backlog: jobs ready to run, and how long the oldest has waited.
      last_value("oban.queue.available_job.count",
        event_name: [:watch_club, :oban, :queue],
        measurement: :available_jobs,
        unit: :"{job}",
        tags: [:"messaging.destination.name"],
        tag_values: &%{"messaging.destination.name": &1.queue}
      ),
      last_value("oban.queue.oldest_available_job.age",
        event_name: [:watch_club, :oban, :queue],
        measurement: :oldest_available_job_age,
        unit: :second,
        tags: [:"messaging.destination.name"],
        tag_values: &%{"messaging.destination.name": &1.queue}
      ),

      # Each attempt of the Req clients that attach ReqTele, retries included
      for event <- [:stop, :error] do
        summary("http.client.request.duration",
          event_name: [:req, :request, :adapter, event],
          unit: {:native, :second},
          tags: [
            :"http.request.method",
            :"server.address",
            :"server.port",
            :"url.template",
            :"http.response.status_code",
            :"error.type"
          ],
          tag_values: &http_client_tags/1,
          reporter_options: [buckets: @duration_buckets]
        )
      end,

      # Content metadata: only Content Type, result and serving path are labels.
      span_summary(
        "watch_club.metadata_fetch.duration",
        [:watch_club, :contents, :metadata_fetch],
        tags: [:"watch_club.content.type", :"watch_club.metadata_fetch.result", :"error.type"],
        tag_values: &metadata_fetch_tags/1,
        reporter_options: [buckets: @duration_buckets]
      ),
      summary("watch_club.metadata_fetch.callers",
        event_name: [:watch_club, :contents, :metadata_fetch],
        unit: :"{caller}",
        tags: [:"watch_club.content.type"],
        tag_values: &%{"watch_club.content.type": &1.type},
        reporter_options: [buckets: [1, 2, 3, 5, 10, 20, 50, 100]]
      ),
      counter("watch_club.metadata_requests",
        event_name: [:watch_club, :contents, :metadata_request],
        measurement: :count,
        unit: :"{request}",
        tags: [:"watch_club.metadata_request.served"],
        tag_values: &%{"watch_club.metadata_request.served": &1.served}
      ),

      # Each Media Import, from its start to its end, by its final status
      summary("watch_club.media_import.duration",
        event_name: [:watch_club, :media_import, :finish],
        unit: {:microsecond, :second},
        tags: [:"watch_club.media_import.status"],
        tag_values: &%{"watch_club.media_import.status": &1.status},
        reporter_options: [buckets: @job_buckets]
      ),

      # Each run of a file's ingest job, by its outcome. A crash is `failed`, with its `error.type`.
      span_summary("watch_club.media_ingest.duration", [:watch_club, :media_ingest],
        tags: [
          :"watch_club.media.type",
          :"watch_club.media_ingest.trigger",
          :"watch_club.media_ingest.outcome",
          :"watch_club.media_ingest.reason",
          :"error.type"
        ],
        tag_values: &media_ingest_tags/1,
        reporter_options: [buckets: @job_buckets]
      ),

      # Which Markers detection finds, and where from. Fingerprints: cache use and decoding time.
      counter("watch_club.marker_detection.markers",
        event_name: [:watch_club, :marker_detection, :marker],
        measurement: :count,
        unit: :"{marker}",
        tags: [:"watch_club.media.type", :"watch_club.marker.kind", :"watch_club.marker.source"],
        tag_values:
          &%{
            "watch_club.media.type": &1.media_type,
            "watch_club.marker.kind": &1.kind,
            "watch_club.marker.source": &1.source
          }
      ),
      counter("watch_club.audio_fingerprint.fetches",
        event_name: [:watch_club, :audio_fingerprint, :fetch],
        measurement: :count,
        unit: :"{fetch}",
        tags: [:"watch_club.audio_fingerprint.cached"],
        tag_values: &%{"watch_club.audio_fingerprint.cached": &1.cached}
      ),
      span_summary(
        "watch_club.audio_fingerprint.compute.duration",
        [:watch_club, :audio_fingerprint, :compute],
        tags: [:"watch_club.audio_fingerprint.part", :"error.type"],
        tag_values:
          &%{"watch_club.audio_fingerprint.part": &1.part, "error.type": exception_type(&1)},
        reporter_options: [buckets: @job_buckets]
      ),

      # Casting: from the Player handing the TV its token to the TV leaving, and why Playback
      # Sessions end. See docs/chromecast.md.
      counter("watch_club.cast.steps",
        event_name: [:watch_club, :cast],
        measurement: :count,
        unit: :"{step}",
        tags: [:"watch_club.cast.result"],
        tag_values: &%{"watch_club.cast.result": &1.result}
      ),
      counter("watch_club.playback_session.endings",
        event_name: [:watch_club, :playback_session, :end],
        measurement: :count,
        unit: :"{session}",
        tags: [:"watch_club.playback_session.end_reason"],
        tag_values: &%{"watch_club.playback_session.end_reason": &1.reason}
      ),

      # The dependency's default poller emits these VM measurements. No OpenTelemetry
      # convention covers the Erlang VM; the names follow its abandoned proposal.
      last_value("beam.memory.allocated",
        event_name: [:vm, :memory],
        measurement: :total,
        unit: :byte
      ),
      last_value("beam.run_queue.length",
        event_name: [:vm, :total_run_queue_lengths],
        measurement: :cpu,
        unit: :"{process}",
        tags: [:"beam.run_queue.type"],
        tag_values: fn _metadata -> %{"beam.run_queue.type": "cpu"} end
      ),
      last_value("beam.run_queue.length",
        event_name: [:vm, :total_run_queue_lengths],
        measurement: :io,
        unit: :"{process}",
        tags: [:"beam.run_queue.type"],
        tag_values: fn _metadata -> %{"beam.run_queue.type": "io"} end
      )
    ])
  end

  # Records a span's :stop and :exception events in one histogram, in seconds
  defp span_summary(name, event_prefix, options) do
    for event <- [:stop, :exception] do
      summary(name, [event_name: event_prefix ++ [event], unit: {:native, :second}] ++ options)
    end
  end

  @doc false
  def measure_job_queues do
    waiting =
      from(job in Oban.Job,
        where: job.state == "available",
        group_by: job.queue,
        select: {job.queue, {count(), min(job.scheduled_at)}}
      )
      |> WatchClub.Repo.all()
      |> Map.new()

    now = DateTime.utc_now()

    # Every configured queue reports, 0 when empty, so no gauge keeps old values.
    for {queue, _limit} <- Application.fetch_env!(:watch_club, Oban)[:queues] do
      queue = to_string(queue)

      measurements =
        case waiting do
          %{^queue => {count, oldest}} ->
            # Waits start at `scheduled_at` and never go below 0, as in Oban's `queue_time`.
            age = max(DateTime.diff(now, oldest, :millisecond), 0) / 1000
            %{available_jobs: count, oldest_available_job_age: age}

          %{} ->
            %{available_jobs: 0, oldest_available_job_age: 0}
        end

      :telemetry.execute([:watch_club, :oban, :queue], measurements, %{queue: queue})
    end
  rescue
    # The poller drops a measurement that raises, which would freeze these gauges.
    DBConnection.ConnectionError -> :ok
  end

  defp http_server_tags(%{conn: conn, route: route} = metadata) do
    # Controllers wrap what they raise with their conn
    failure =
      case metadata do
        %{reason: %Plug.Conn.WrapperError{kind: kind, reason: reason}} ->
          %{kind: kind, reason: reason}

        _ ->
          metadata
      end

    # Plug turns some exceptions, such as a missing record, into a 4xx response
    status =
      case failure do
        %{kind: :error, reason: reason} -> Plug.Exception.status(reason)
        %{kind: _kind} -> 500
        _ -> conn.status
      end

    %{
      "http.request.method": conn.method,
      "url.scheme": Atom.to_string(conn.scheme),
      "http.route": route,
      "http.response.status_code": status,
      "error.type":
        if(status in 500..599, do: exception_type(failure) || Integer.to_string(status))
    }
  end

  defp live_view_tags(%{socket: socket} = metadata) do
    %{
      "phoenix.live_view.module": inspect(socket.view),
      "phoenix.live_view.connected": Phoenix.LiveView.connected?(socket),
      "phoenix.live_view.event": event_name(metadata),
      "error.type": exception_type(metadata)
    }
  end

  # A failed event may have any name a client sent, which would make a label per name
  defp event_name(%{kind: _kind}), do: "_OTHER"
  defp event_name(metadata), do: metadata[:event]

  # Postgres reports a failed query with its SQLSTATE code
  defp database_tags(%{source: source, result: result}, database) do
    {operation, status_code, error_type} =
      case result do
        {:ok, %Postgrex.Result{command: command}} when is_atom(command) and command != nil ->
          {command |> Atom.to_string() |> String.upcase(), nil, nil}

        # Several commands, such as a rollback to a savepoint, have no single operation name
        {:ok, _result} ->
          {nil, nil, nil}

        {:error, %Postgrex.Error{postgres: %{pg_code: code}}} ->
          {nil, code, code}

        {:error, error} ->
          {nil, nil, exception_type(%{kind: :error, reason: error})}
      end

    %{
      "db.system.name": "postgresql",
      "db.namespace": database,
      "db.collection.name": source,
      "db.operation.name": operation,
      "db.response.status_code": status_code,
      "error.type": error_type
    }
  end

  defp job_tags(%{job: job} = metadata) do
    %{
      "messaging.system": "oban",
      "messaging.operation.name": "process",
      "messaging.destination.name": job.queue,
      "oban.job.worker": job.worker,
      "error.type": exception_type(metadata)
    }
  end

  # Matches the attributes OpentelemetryReq puts on each attempt's span
  defp http_client_tags(%{request: request} = metadata) do
    {status, error_type} =
      case metadata do
        %{status: status} when status >= 400 -> {status, Integer.to_string(status)}
        %{status: status} -> {status, nil}
        %{error: exception} -> {nil, inspect(exception.__struct__)}
      end

    %{
      "http.request.method": request.method |> Atom.to_string() |> String.upcase(),
      "server.address": request.url.host,
      "server.port": request.url.port,
      # Only requests with path_params have a template, which keeps IDs out of the labels
      "url.template": Req.Request.get_private(request, :path_params_template),
      "http.response.status_code": status,
      "error.type": error_type
    }
  end

  # Like the fetch's span, results other than created or refreshed are errors
  defp metadata_fetch_tags(metadata) do
    %{
      "watch_club.content.type": metadata.type,
      "watch_club.metadata_fetch.result": metadata[:result],
      "error.type":
        case metadata do
          %{result: result} when result in [:created, :refreshed] -> nil
          %{result: result} -> Atom.to_string(result)
          _crashed -> exception_type(metadata)
        end
    }
  end

  # A crash's metadata has the exception as its `reason`, so it can't share the outcome's clause
  defp media_ingest_tags(%{kind: _kind} = metadata) do
    %{
      "watch_club.media.type": metadata.media_type,
      "watch_club.media_ingest.trigger": metadata.trigger,
      "watch_club.media_ingest.outcome": :failed,
      "error.type": exception_type(metadata)
    }
  end

  defp media_ingest_tags(metadata) do
    %{
      "watch_club.media.type": metadata.media_type,
      "watch_club.media_ingest.trigger": metadata.trigger,
      "watch_club.media_ingest.outcome": metadata.outcome,
      "watch_club.media_ingest.reason": metadata.reason
    }
  end

  # Names what a span raised, or nil when it raised nothing
  defp exception_type(%{kind: :error, reason: reason}),
    do: inspect(Exception.normalize(:error, reason).__struct__)

  defp exception_type(%{kind: kind}), do: Atom.to_string(kind)
  defp exception_type(_metadata), do: nil
end
