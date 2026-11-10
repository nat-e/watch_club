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
      # HTTP requests the router handles
      summary("http.server.request.duration",
        event_name: [:phoenix, :router_dispatch, :stop],
        unit: {:native, :second},
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
        tags: [:"db.system.name", :"db.collection.name", :"error.type"],
        tag_values: &database_tags/1,
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
      summary("messaging.process.duration",
        event_name: [:oban, :job, :stop],
        unit: {:native, :second},
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
      summary("oban.job.queue_time",
        event_name: [:oban, :job, :stop],
        unit: {:native, :second},
        tags: [:"messaging.destination.name", :"oban.job.worker"],
        tag_values: &job_tags/1,
        reporter_options: [buckets: @job_buckets]
      ),

      # TMDB HTTP attempts, with endpoint templates instead of individual IDs.
      summary("http.client.request.duration",
        event_name: [:watch_club, :tmdb, :request, :stop],
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
      ),

      # Content metadata: only Content Type, result and serving path are labels.
      summary("watch_club.metadata_fetch.duration",
        event_name: [:watch_club, :contents, :metadata_fetch, :stop],
        unit: {:native, :second},
        tags: [:"watch_club.content.type", :"watch_club.metadata_fetch.result", :"error.type"],
        tag_values:
          &%{
            "watch_club.content.type": &1.type,
            "watch_club.metadata_fetch.result": &1[:result],
            "error.type": error_type(&1)
          },
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
        unit: :"{request}",
        tags: [:"watch_club.metadata_request.served"],
        tag_values: &%{"watch_club.metadata_request.served": &1.served}
      ),
      counter("watch_club.media_import.matches",
        event_name: [:watch_club, :media_import, :match],
        unit: :"{match}",
        tags: [:"watch_club.media_import.match.result"],
        tag_values: &%{"watch_club.media_import.match.result": &1.result}
      ),

      # Which Markers detection finds, and where from. Fingerprints: cache use and decoding time.
      counter("watch_club.marker_detection.markers",
        event_name: [:watch_club, :marker_detection, :marker],
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
        unit: :"{fetch}",
        tags: [:"watch_club.audio_fingerprint.cached"],
        tag_values: &%{"watch_club.audio_fingerprint.cached": &1.cached}
      ),
      summary("watch_club.audio_fingerprint.compute.duration",
        event_name: [:watch_club, :audio_fingerprint, :compute, :stop],
        unit: {:native, :second},
        tags: [:"watch_club.audio_fingerprint.part", :"error.type"],
        tag_values:
          &%{"watch_club.audio_fingerprint.part": &1.part, "error.type": error_type(&1)},
        reporter_options: [buckets: @job_buckets]
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
    ]
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
      "error.type": if(status in 500..599, do: error_type(failure) || Integer.to_string(status))
    }
  end

  defp database_tags(%{source: source, result: result}) do
    %{
      "db.system.name": "postgresql",
      "db.collection.name": source,
      "error.type":
        case result do
          {:ok, _result} -> nil
          {:error, error} -> error_type(%{kind: :error, reason: error})
        end
    }
  end

  defp job_tags(%{job: job} = metadata) do
    %{
      "messaging.system": "oban",
      "messaging.operation.name": "process",
      "messaging.destination.name": job.queue,
      "oban.job.worker": job.worker,
      "error.type": error_type(metadata)
    }
  end

  # Matches the attributes OpentelemetryReq puts on the request's span
  defp http_client_tags(%{request: request, response: response}) do
    {status, error_type} =
      case response do
        %Req.Response{status: status} when status >= 400 -> {status, Integer.to_string(status)}
        %Req.Response{status: status} -> {status, nil}
        exception -> {nil, inspect(exception.__struct__)}
      end

    %{
      "http.request.method": request.method |> Atom.to_string() |> String.upcase(),
      "server.address": request.url.host,
      "server.port": request.url.port,
      "url.template": Req.Request.get_private(request, :path_params_template),
      "http.response.status_code": status,
      "error.type": error_type
    }
  end

  # Names what a span raised, or nil when it succeeded
  defp error_type(%{kind: :error, reason: reason}),
    do: inspect(Exception.normalize(:error, reason).__struct__)

  defp error_type(%{kind: kind}), do: Atom.to_string(kind)
  defp error_type(_metadata), do: nil
end
