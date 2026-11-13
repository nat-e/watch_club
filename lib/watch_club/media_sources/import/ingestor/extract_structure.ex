defmodule WatchClub.MediaSources.Import.Ingestor.ExtractStructure do
  @moduledoc """
  Populates `candidate.media_structure` with the file's technical shape —
  container, duration, and tracks. Dispatches by `candidate.media_type`:

    * `:video` → probe with `ffprobe`, build the structure, read the keyframes,
      append sidecar text tracks, and compute the File Fingerprint.
    * `:audiobook` → probe with `ffprobe`, build the structure.
    * `:ebook` → record the file extension as container; no probing.
  """

  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MediaStructure
  alias WatchClub.MediaSources.Import.Ingestor.ExtractStructure.{Sidecars, Tracks}

  @ffprobe Application.compile_env(:watch_club, :ffprobe, WatchClub.Ffmpeg)

  # The File Fingerprint reads this many bytes at each end of the file
  @fingerprint_sample_bytes 64 * 1024

  @doc "Returns the Candidate with its `media_structure`, or `{:error, reason}` when the file can't be read."
  def apply(%Candidate{media_type: media_type} = candidate), do: probe(media_type, candidate)

  defp probe(media_type, candidate)
       when media_type in [:movie, :tv_show_episode, :sports_event] do
    with {:ok, metadata} <- @ffprobe.probe(candidate.path),
         {:ok, structure} <- Tracks.for_video(metadata),
         {:ok, keyframe_seconds} <- @ffprobe.keyframes(candidate.path),
         {:ok, fingerprint} <- file_fingerprint(candidate.path) do
      structure = %{structure | file_fingerprint: fingerprint, keyframe_seconds: keyframe_seconds}
      {:ok, Sidecars.append(%{candidate | media_structure: structure})}
    end
  end

  defp probe(:audiobook, candidate) do
    with {:ok, metadata} <- @ffprobe.probe(candidate.path),
         {:ok, structure} <- Tracks.for_audiobook(metadata) do
      {:ok, %{candidate | media_structure: structure}}
    end
  end

  defp probe(:ebook, candidate) do
    structure = %MediaStructure{container: container_from_path(candidate.path)}
    {:ok, %{candidate | media_structure: structure}}
  end

  # The size and both ends of the file tell a replaced file apart, reading only 128 KB. The
  # modification time can't: Radarr and Sonarr can give a new file the date of the old one.
  defp file_fingerprint(path) do
    with {:ok, %File.Stat{size: size}} <- File.stat(path) do
      File.open(path, [:read, :raw, :binary], fn file ->
        {:ok, samples} =
          :file.pread(file, [
            {0, @fingerprint_sample_bytes},
            {max(size - @fingerprint_sample_bytes, 0), @fingerprint_sample_bytes}
          ])

        :crypto.hash(:sha256, [Integer.to_string(size) | samples]) |> Base.encode16(case: :lower)
      end)
    end
  end

  defp container_from_path(path) do
    case path |> Path.extname() |> String.trim_leading(".") do
      "" -> nil
      ext -> ext
    end
  end
end
