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
         # Gone until the next scan removes its Media
         {:ok, %File.Stat{type: :regular} = stat} <- File.stat(media.path, time: :posix) do
      # Changes with the file, so a resumed download never mixes two files
      etag = ~s("#{stat.size}-#{stat.mtime}")

      conn
      |> put_resp_header("content-type", MIME.from_path(media.path))
      |> put_resp_header("content-disposition", content_disposition(media.file_name))
      |> put_resp_header("accept-ranges", "bytes")
      |> put_resp_header("etag", etag)
      |> send_range(media.path, stat.size, requested_range(conn, etag))
    else
      _not_found -> conn |> put_resp_content_type("text/plain") |> send_resp(404, "Not found")
    end
  end

  # The Range header's value, unless it asks for a file the ETag in If-Range no longer matches
  defp requested_range(conn, etag) do
    case {get_req_header(conn, "range"), get_req_header(conn, "if-range")} do
      {[range], []} -> range
      {[range], [^etag]} -> range
      _whole_file -> nil
    end
  end

  # A single range of bytes, such as "bytes=1000-", "bytes=1000-1999" or the last bytes with
  # "bytes=-500". Anything else gets the whole file.
  defp send_range(conn, path, size, "bytes=" <> spec) do
    case byte_range(spec, size) do
      {first, last} ->
        conn
        |> put_resp_header("content-range", "bytes #{first}-#{last}/#{size}")
        |> send_file(206, path, first, last - first + 1)

      :unsatisfiable ->
        conn |> put_resp_header("content-range", "bytes */#{size}") |> send_resp(416, "")

      :invalid ->
        send_file(conn, 200, path)
    end
  end

  defp send_range(conn, path, _size, _range), do: send_file(conn, 200, path)

  defp byte_range(spec, size) do
    case Integer.parse(spec) do
      {first, "-"} when first >= 0 and first < size ->
        {first, size - 1}

      {first, "-" <> last} when first >= 0 and first < size ->
        case Integer.parse(last) do
          {last, ""} when last >= first -> {first, min(last, size - 1)}
          _invalid -> :invalid
        end

      # "-500" parses as a negative first byte
      {suffix, ""} when suffix < 0 and size > 0 ->
        {max(size + suffix, 0), size - 1}

      {first, "-" <> _last} when first >= size ->
        :unsatisfiable

      _invalid ->
        :invalid
    end
  end

  # An ASCII name for old browsers, then the real one, which current browsers use (RFC 6266)
  defp content_disposition(file_name) do
    ascii_name = String.replace(file_name, ~r/[^\x20-\x7E]|["\\]/u, "_")

    ~s(attachment; filename="#{ascii_name}"; filename*=UTF-8''#{URI.encode(file_name, &URI.char_unreserved?/1)})
  end
end
