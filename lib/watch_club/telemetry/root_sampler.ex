defmodule WatchClub.Telemetry.RootSampler do
  @moduledoc false
  @behaviour :otel_sampler

  @impl true
  def setup(_opts), do: []

  @impl true
  def description(_config), do: "WatchClubRootSampler"

  @impl true
  def should_sample(context, _trace_id, _links, _name, kind, attributes, _config) do
    decision =
      case {kind, attributes} do
        {:server, %{:"url.path" => "/health"}} -> :drop
        {:client, %{:"db.system" => _}} -> :drop
        _ -> :record_and_sample
      end

    tracestate = context |> :otel_tracer.current_span_ctx() |> :otel_span.tracestate()
    {decision, [], tracestate}
  end
end
