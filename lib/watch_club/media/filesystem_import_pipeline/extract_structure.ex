defmodule WatchClub.Media.ImportPipeline.ExtractStructure do
  @moduledoc """
  Populates `candidate.media_structure` with the file's technical shape —
  container, duration, and tracks. Dispatches by `configuration.media_type`:

    * `:video` → probe with `ffprobe`, build the structure, append sidecar
      text tracks.
    * `:audiobook` → probe with `ffprobe`, build the structure.
    * `:ebook` → record the file extension as container; no probing.
  """

  @behaviour WatchClub.Media.ImportPipeline.Stage

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.MediaStructure
  alias WatchClub.Media.ImportPipeline.ExtractStructure.{Sidecars, Tracks}
  alias WatchClub.Media.ImportRun

  require Logger

  @ffprobe Application.compile_env(:watch_club, :ffprobe, WatchClub.Media.Ffmpeg)

  @impl true
  def apply(%Candidate{} = candidate, %ImportRun{snapshot_configuration: configuration}) do
    Logger.debug("Extracting structure for #{candidate}")

    case probe(configuration.media_type, candidate) do
      {:ok, candidate} -> {:ok, candidate}
      {:error, reason} -> {:halt, reason}
    end
  end

  defp probe(media_type, candidate) when media_type in [:movie, :tv_show_episode] do
    with {:ok, metadata} <- @ffprobe.probe(candidate.path),
         {:ok, structure} <- Tracks.for_video(metadata) do
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

  defp container_from_path(path) do
    case path |> Path.extname() |> String.trim_leading(".") do
      "" -> nil
      ext -> ext
    end
  end
end
