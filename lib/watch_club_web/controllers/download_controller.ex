defmodule WatchClubWeb.DownloadController do
  @moduledoc """
  Downloads a Media's file under its own name. It answers a single byte range, so a browser can
  resume a dropped download of a large file.
  """
  use WatchClubWeb, :controller

  alias WatchClub.MediaCatalog

  def show(conn, %{"media_id" => media_id}) do
    with {:ok, media} <-
           MediaCatalog.get_media_to_download(media_id,
             load: [:file_name],
             actor: conn.assigns.current_user
           ),
         {:ok, stat} <- File.stat(media.path, time: :posix) do
      # Changes with the file, so a resumed download never mixes two files
      etag = ~s("#{stat.size}-#{stat.mtime}")
      conn = conn |> put_resp_header("accept-ranges", "bytes") |> put_resp_header("etag", etag)

      case byte_range(conn, etag, stat.size) do
        :whole ->
          send_download(conn, {:file, media.path}, filename: media.file_name)

        {first, last} ->
          conn
          |> put_status(206)
          |> put_resp_header("content-range", "bytes #{first}-#{last}/#{stat.size}")
          |> send_download({:file, media.path},
            filename: media.file_name,
            offset: first,
            length: last - first + 1
          )

        :unsatisfiable ->
          conn |> put_resp_header("content-range", "bytes */#{stat.size}") |> send_resp(416, "")
      end
    else
      # Unknown, or hidden from the actor
      {:error, %Ash.Error.Invalid{}} -> send_not_found(conn)
      # Gone until the next scan removes its Media
      {:error, :enoent} -> send_not_found(conn)
    end
  end

  # The bytes a resuming browser asks for. Several ranges, anything malformed, or an If-Range for
  # an older file get the whole file.
  defp byte_range(conn, etag, size) do
    with {["bytes=" <> spec], if_range} when if_range in [[], [etag]] <-
           {get_req_header(conn, "range"), get_req_header(conn, "if-range")},
         [from, to] <- String.split(spec, "-") do
      case {Integer.parse(from), Integer.parse(to)} do
        # The last bytes, as "bytes=-500"
        {:error, {count, ""}} when count > 0 and size > 0 ->
          {max(size - count, 0), size - 1}

        # To the end, as "bytes=1000-"
        {{first, ""}, :error} when to == "" and first < size ->
          {first, size - 1}

        # Between two bytes, as "bytes=1000-1999"
        {{first, ""}, {last, ""}} when first <= last and first < size ->
          {first, min(last, size - 1)}

        {{first, ""}, _to} when first >= size ->
          :unsatisfiable

        _malformed ->
          :whole
      end
    else
      _whole_file -> :whole
    end
  end

  defp send_not_found(conn),
    do: conn |> put_resp_content_type("text/plain") |> send_resp(404, "Not found")
end
