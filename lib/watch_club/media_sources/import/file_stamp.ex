defmodule WatchClub.MediaSources.Import.FileStamp do
  @moduledoc """
  The File Stamp of a Media's file: a hash of the size, change time and modification time of the
  file and, for a Video, of the subtitle files next to it. A Media Import processes a file again
  when its File Stamp changed, and reads only this otherwise.

  The change time is the system's, which apps can't set, while Radarr and Sonarr can give a new
  file the modification time of the old one. A new hard link or new permissions change it too,
  which only processes the file once more.
  """

  alias WatchClub.MediaSources.Import.Ingestor.ExtractStructure.Sidecars

  @doc "The File Stamp of the file at `path`, or nil when the file can't be read."
  @spec read(String.t(), atom()) :: String.t() | nil
  def read(path, media_type) do
    case File.stat(path, time: :posix) do
      {:ok, stat} ->
        # A sidecar removed since it was listed has no line
        sidecar_lines =
          for sidecar <- sidecars(path, media_type),
              {:ok, sidecar_stat} <- [File.stat(sidecar, time: :posix)],
              do: line(Path.basename(sidecar), sidecar_stat)

        :crypto.hash(:sha256, [line("", stat) | sidecar_lines]) |> Base.encode16(case: :lower)

      {:error, _reason} ->
        nil
    end
  end

  defp sidecars(path, media_type) when media_type in [:movie, :tv_show_episode, :sports_event],
    do: Sidecars.paths(path)

  defp sidecars(_path, _media_type), do: []

  defp line(name, %File.Stat{} = stat), do: "#{name}:#{stat.size}:#{stat.ctime}:#{stat.mtime}\n"
end
