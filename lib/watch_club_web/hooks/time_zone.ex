defmodule WatchClubWeb.Hooks.TimeZone do
  @moduledoc """
  Assigns `time_zone`, the browser's time zone, which it sends when the page connects. It's UTC
  until then, or when the browser sends a time zone the database doesn't know.
  """
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, _session, socket) do
    time_zone =
      case Phoenix.LiveView.get_connect_params(socket) do
        %{"time_zone" => time_zone} when is_binary(time_zone) -> known_or_utc(time_zone)
        _params -> "Etc/UTC"
      end

    {:cont, assign(socket, :time_zone, time_zone)}
  end

  defp known_or_utc(time_zone) do
    case DateTime.now(time_zone) do
      {:ok, _now} -> time_zone
      {:error, _reason} -> "Etc/UTC"
    end
  end
end
