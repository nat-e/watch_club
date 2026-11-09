defmodule WatchClub.Contents.MetadataFetcher do
  @moduledoc false
  use GenServer

  alias OpenTelemetry.{Ctx, Span}
  alias WatchClub.Contents
  alias WatchClub.Contents.{ContentIdentity, MetadataUnavailable}
  alias WatchClub.SystemActor

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, nil, Keyword.put(opts, :name, __MODULE__))

  @doc "Creates or refreshes Content, sharing an in-flight fetch with every caller for its identity."
  @spec fetch(ContentIdentity.t()) :: {:ok, WatchClub.Contents.Content.t()} | {:error, term()}
  def fetch(identity) do
    case GenServer.call(__MODULE__, {:fetch, identity, Ctx.get_current()}, :infinity) do
      {:exit, reason} -> exit(reason)
      result -> result
    end
  end

  @impl true
  def init(nil), do: {:ok, %{}}

  @impl true
  def handle_call({:fetch, identity, context}, from, fetches) do
    fetch =
      case Map.get(fetches, identity) do
        nil ->
          started_at = OpenTelemetry.timestamp()

          span =
            Tracer.start_span(context, "watch_club.contents.metadata_fetch", %{
              start_time: started_at,
              attributes: %{
                "watch_club.content.type" => to_string(identity.type),
                "watch_club.content.tmdb_id" => identity.external_id
              }
            })

          # Propagator Task wrappers would only copy the GenServer's empty process-dictionary context.
          task =
            Task.Supervisor.async_nolink(__MODULE__.TaskSupervisor, fn ->
              Ctx.attach(context)
              Tracer.set_current_span(span)
              fetch_content!(identity)
            end)

          %{task: task, span: span, started_at: started_at, callers: [{from, context, nil}]}

        fetch ->
          %{fetch | callers: [{from, context, OpenTelemetry.timestamp()} | fetch.callers]}
      end

    {:noreply, Map.put(fetches, identity, fetch)}
  end

  @impl true
  def handle_info({ref, {result, reply}}, fetches) do
    {identity, fetch} = Enum.find(fetches, fn {_identity, fetch} -> fetch.task.ref == ref end)
    Process.demonitor(ref, [:flush])

    :telemetry.execute(
      [:watch_club, :contents, :metadata_fetch, :stop],
      %{duration: OpenTelemetry.timestamp() - fetch.started_at, callers: length(fetch.callers)},
      %{type: identity.type, result: result}
    )

    reply_to_callers(identity, fetch, result, reply)
    {:noreply, Map.delete(fetches, identity)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, fetches) do
    {identity, fetch} = Enum.find(fetches, fn {_identity, fetch} -> fetch.task.ref == ref end)

    {exception, stacktrace} =
      case reason do
        {exception, stacktrace} when is_exception(exception) and is_list(stacktrace) ->
          {exception, stacktrace}

        reason ->
          {Exception.normalize(:error, reason), []}
      end

    Span.record_exception(fetch.span, exception, stacktrace)

    Logger.warning(
      "Content metadata fetch crashed for #{identity.type} TMDB #{identity.external_id}: " <>
        Exception.message(exception),
      [
        event: :content_metadata_unavailable,
        content_type: identity.type,
        tmdb_id: identity.external_id,
        reason: Exception.message(exception)
      ] ++ Map.to_list(Span.hex_span_ctx(fetch.span))
    )

    :telemetry.execute(
      [:watch_club, :contents, :metadata_fetch, :exception],
      %{duration: OpenTelemetry.timestamp() - fetch.started_at, callers: length(fetch.callers)},
      %{type: identity.type, kind: :exit, reason: reason, stacktrace: stacktrace}
    )

    reply_to_callers(identity, fetch, :crashed, {:exit, reason})
    {:noreply, Map.delete(fetches, identity)}
  end

  defp reply_to_callers(identity, fetch, result, reply) do
    callers = length(fetch.callers)

    :telemetry.execute(
      [:watch_club, :contents, :metadata_fetch],
      %{callers: callers},
      %{type: identity.type}
    )

    attributes = %{
      "watch_club.content.type" => to_string(identity.type),
      "watch_club.content.tmdb_id" => identity.external_id,
      "watch_club.metadata_fetch.result" => to_string(result),
      "watch_club.metadata_fetch.callers" => callers
    }

    status =
      if result in [:created, :refreshed],
        do: OpenTelemetry.status(:ok),
        else: OpenTelemetry.status(:error, to_string(result))

    Span.set_attributes(fetch.span, attributes)
    Span.set_status(fetch.span, status)
    Span.end_span(fetch.span)

    Enum.each(fetch.callers, fn {from, context, joined_at} ->
      if joined_at do
        # Links are accepted only at span creation; backdate the span to when this caller joined.
        span =
          Tracer.start_span(context, "watch_club.contents.metadata_fetch.wait", %{
            start_time: joined_at,
            links: OpenTelemetry.links([fetch.span]),
            attributes: attributes
          })

        Span.set_status(span, status)
        Span.end_span(span)
      end

      GenServer.reply(from, reply)
    end)
  end

  defp fetch_content!(identity) do
    content =
      Contents.get_content_by_identity!(identity,
        not_found_error?: false,
        actor: SystemActor.actor()
      )

    result =
      if content,
        do: Contents.refresh_metadata(content, %{}, actor: SystemActor.actor()),
        else: Contents.create_content(identity, actor: SystemActor.actor())

    case result do
      {:ok, refreshed} ->
        {if(content, do: :refreshed, else: :created), {:ok, refreshed}}

      {:error, error} ->
        case Enum.find(error.errors, &match?(%MetadataUnavailable{}, &1)) do
          %MetadataUnavailable{reason: reason} ->
            Logger.warning(
              "Content metadata is unavailable for #{identity.type} TMDB #{identity.external_id}: #{inspect(reason)}",
              event: :content_metadata_unavailable,
              content_type: identity.type,
              tmdb_id: identity.external_id,
              reason: reason
            )

            cond do
              content -> {:kept_stored, {:ok, content}}
              reason == :not_found -> {:not_found, {:error, error}}
              true -> {:unavailable, {:error, error}}
            end

          nil ->
            raise error
        end
    end
  end
end
