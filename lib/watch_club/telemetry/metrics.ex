defmodule WatchClub.Telemetry.Metrics do
  @moduledoc false

  use GenServer

  alias Telemetry.Metrics.{Counter, LastValue, Sum, Summary}

  def start_link(metrics) do
    GenServer.start_link(__MODULE__, metrics, name: __MODULE__)
  end

  @impl true
  def init(metrics) do
    Process.flag(:trap_exit, true)
    :ets.new(__MODULE__, [:named_table, :public, write_concurrency: true])

    scope =
      :opentelemetry.instrumentation_scope(
        "watch_club",
        Application.spec(:watch_club, :vsn) |> to_string(),
        ""
      )

    meter = :otel_meter_provider.get_meter(scope)

    handlers =
      metrics
      |> Enum.group_by(& &1.event_name)
      |> Enum.map(fn {event, metrics} ->
        instruments =
          Enum.map(metrics, fn metric ->
            # Names come only from the application's fixed metric definitions.
            name = metric.name |> Enum.join(".") |> String.to_atom()
            options = %{description: metric.description || "", unit: unit(metric.unit)}

            case metric do
              %Counter{} ->
                :otel_meter.create_counter(meter, name, options)

              %Sum{} ->
                :otel_meter.create_counter(meter, name, options)

              %Summary{} ->
                options =
                  Map.put(options, :advisory_params, %{
                    explicit_bucket_boundaries: Keyword.fetch!(metric.reporter_options, :buckets)
                  })

                :otel_meter.create_histogram(meter, name, options)

              %LastValue{} ->
                :otel_meter.create_observable_gauge(
                  meter,
                  name,
                  &__MODULE__.observe/1,
                  name,
                  options
                )
            end

            {metric, name}
          end)

        id = {__MODULE__, event}
        :telemetry.detach(id)
        :ok = :telemetry.attach(id, event, &__MODULE__.handle_event/4, {meter, instruments})
        id
      end)

    {:ok, handlers}
  end

  def handle_event(_event, measurements, metadata, {meter, instruments}) do
    for {metric, name} <- instruments do
      value =
        case metric do
          %Counter{} ->
            1

          %{measurement: measurement} when is_function(measurement, 1) ->
            measurement.(measurements)

          %{measurement: measurement} when is_function(measurement, 2) ->
            measurement.(measurements, metadata)

          %{measurement: measurement} ->
            Map.get(measurements, measurement)
        end

      if is_number(value) do
        attributes = metadata |> metric.tag_values.() |> Map.take(metric.tags)

        case metric do
          %LastValue{} ->
            :ets.insert(__MODULE__, {{name, attributes}, value})

          _ ->
            :otel_meter.record(:otel_ctx.get_current(), meter, name, value, attributes)
        end
      end
    end
  end

  def observe(name) do
    case :ets.whereis(__MODULE__) do
      :undefined ->
        []

      table ->
        for {{^name, attributes}, value} <- :ets.match_object(table, {{name, :_}, :_}),
            do: {value, attributes}
    end
  end

  @impl true
  def terminate(_reason, handlers) do
    Enum.each(handlers, &:telemetry.detach/1)
  end

  defp unit(:second), do: "s"
  defp unit(:byte), do: "By"
  defp unit(:unit), do: "1"
end
