defmodule WatchClubWeb.DownloadController do
  @moduledoc """
  Downloads a Media's original file under its own name. It answers HTTP range requests, so the
  browser can resume an interrupted download of a large file.
  """
  use WatchClubWeb, :controller

  alias WatchClub.MediaCatalog

  def download(conn, %{"media_id" => media_id}) do
    case MediaCatalog.get_media(media_id, actor: conn.assigns.current_user) do
      {:ok, media} ->
        send_media_file!(conn, media.path)

      {:error, _not_found} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Not found")
    end
  end

  defp send_media_file!(conn, path) do
    %File.Stat{size: size, mtime: mtime} = File.stat!(path, time: :posix)
    # Changes when the file is replaced, so a resumed download never joins two different files
    etag = ~s("#{size}-#{mtime}")

    conn =
      conn
      |> put_resp_header("accept-ranges", "bytes")
      |> put_resp_header("etag", etag)

    case requested_range(conn, size, etag) do
      {first, last} ->
        conn
        |> put_status(206)
        |> put_resp_header("content-range", "bytes #{first}-#{last}/#{size}")
        |> send_download({:file, path}, offset: first, length: last - first + 1)

      :unsatisfiable ->
        conn
        |> put_resp_header("content-range", "bytes */#{size}")
        |> send_resp(416, "")

      :entire_file ->
        send_download(conn, {:file, path})
    end
  end

  # The one byte range the browser asks for, unless the file changed since it got the first bytes
  # (If-Range). Anything else, such as several ranges, gets the entire file, as HTTP allows.
  defp requested_range(conn, size, etag) do
    with [range] <- get_req_header(conn, "range"),
         true <- get_req_header(conn, "if-range") in [[], [etag]],
         [_range, first, last] when first != "" or last != "" <-
           Regex.run(~r/\Abytes=(\d*)-(\d*)\z/, range) do
      byte_range(first, last, size)
    else
      _no_usable_range -> :entire_file
    end
  end

  # The first and last byte of "500-999", "500-" to the end, or "-500" for the last 500 bytes
  defp byte_range(first, last, size) do
    {first, last} =
      case {first, last} do
        {"", suffix_length} -> {size - String.to_integer(suffix_length), size - 1}
        {first, ""} -> {String.to_integer(first), size - 1}
        {first, last} -> {String.to_integer(first), min(String.to_integer(last), size - 1)}
      end

    cond do
      first >= size -> :unsatisfiable
      first > last -> :entire_file
      true -> {max(first, 0), last}
    end
  end
end
