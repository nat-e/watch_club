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

  alias WatchClub.Media.Ffmpeg
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.MediaStructure
  alias WatchClub.Media.ImportPipeline.ExtractStructure.{Sidecars, Tracks}
  alias WatchClub.Media.ImportRun

  @impl true
  def apply(%Candidate{} = candidate, %ImportRun{snapshot_configuration: configuration}) do
    case probe(configuration.media_type, candidate) do
      {:ok, candidate} -> {:ok, candidate}
      {:error, reason} -> {:halt, reason}
    end
  end

  defp probe(media_type, candidate) when media_type in [:movie, :tv_show_episode] do
    with {:ok, metadata} <- Ffmpeg.probe(candidate.path),
         {:ok, structure} <- Tracks.for_video(metadata) do
      {:ok, Sidecars.append(%{candidate | media_structure: structure})}
    end
  end

  defp probe(:audiobook, candidate) do
    with {:ok, metadata} <- Ffmpeg.probe(candidate.path),
         {:ok, structure} <- Tracks.for_audiobook(metadata) do
      {:ok, %{candidate | media_structure: structure}}
    end
  end

  defp probe(:ebook, candidate) do
    structure = %MediaStructure{
      container: candidate.extension |> String.trim_leading(".") |> empty_to_nil()
    }

    {:ok, %{candidate | media_structure: structure}}
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value
end
