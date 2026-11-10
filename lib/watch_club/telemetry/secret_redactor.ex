defmodule WatchClub.Telemetry.SecretRedactor do
  @moduledoc """
  Span processor that replaces the values of secret query parameters with `REDACTED` in
  `url.query` and `url.full`, keeping their names, as OpenTelemetry's URL conventions ask.

  A processor can only change a span when it starts, and HTTP instrumentations set these
  attributes then. List it before the batch processor, with the exact parameter names in
  `secret_params`.
  """
  @behaviour :otel_span_processor

  require Record

  Record.defrecordp(
    :span,
    Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
  )

  @impl true
  def on_start(_ctx, span(attributes: attributes) = span, %{secret_params: secret_params}) do
    redacted =
      attributes
      |> :otel_attributes.map()
      |> Map.take([:"url.query", :"url.full"])
      |> Map.new(fn
        {:"url.query", query} -> {:"url.query", redact_query(query, secret_params)}
        {:"url.full", url} -> {:"url.full", redact_url(url, secret_params)}
      end)

    span(span, attributes: :otel_attributes.set(redacted, attributes))
  end

  @impl true
  def on_end(_span, _config), do: true

  @impl true
  def force_flush(_config), do: :ok

  defp redact_url(url, secret_params) do
    case URI.parse(url) do
      %URI{query: query} = uri when is_binary(query) ->
        URI.to_string(%{uri | query: redact_query(query, secret_params)})

      _ ->
        url
    end
  end

  # Names are compared as sent, without decoding, so a malformed query can't raise.
  defp redact_query(query, secret_params) do
    query
    |> String.split("&")
    |> Enum.map_join("&", fn pair ->
      case String.split(pair, "=", parts: 2) do
        [name, _value] -> if name in secret_params, do: name <> "=REDACTED", else: pair
        [_name] -> pair
      end
    end)
  end
end
