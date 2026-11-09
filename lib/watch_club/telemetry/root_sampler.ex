defmodule WatchClub.Telemetry.RootSampler do
  @moduledoc false
  @behaviour :otel_sampler

  # Health checks and LiveView long-polls, as path segments so extra slashes match like in Phoenix.
  @dropped_paths [["health"], ["live", "longpoll"]]

  @impl true
  def setup(_opts), do: []

  @impl true
  def description(_config), do: "WatchClubRootSampler"

  @impl true
  def should_sample(context, _trace_id, _links, _name, kind, attributes, _config) do
    decision =
      case {kind, attributes} do
        {:server, %{:"url.path" => path}} ->
          if String.split(path, "/", trim: true) in @dropped_paths,
            do: :drop,
            else: :record_and_sample

        {:client, %{:"db.system" => _}} ->
          :drop

        _ ->
          :record_and_sample
      end

    tracestate = context |> :otel_tracer.current_span_ctx() |> :otel_span.tracestate()
    {decision, [], tracestate}
  end
end
