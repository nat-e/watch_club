defmodule WatchClub.Media.ImportPipeline.FilterExisting do
  @moduledoc """
  Decides whether a candidate continues through the pipeline based on whether
  Media already exists at its path.

    * No existing Media → continue.
    * Existing Media and refresh on → continue, tagged for refresh via
      `:existing_media`.
    * Existing Media and refresh off → halt as `:skipped` (no result row,
      per `CONTEXT.md`).
    * Lookup error → halt as `:failed`.
  """

  @behaviour WatchClub.Media.ImportPipeline.Stage

  alias WatchClub.Media, as: MediaDomain
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportRun
  alias WatchClub.Media.Media
  alias WatchClub.SystemActor

  @impl true
  def apply(%Candidate{} = candidate, %ImportRun{refresh_metadata?: refresh_metadata?}) do
    case existing_media(candidate.path) do
      {:ok, nil} ->
        {:ok, candidate}

      {:ok, %Media{id: id, type: type}} when refresh_metadata? ->
        {:ok, %{candidate | existing_media: %{id: id, type: type}}}

      {:ok, %Media{}} ->
        {:halt, candidate, :skipped, nil}

      {:error, error} ->
        {:halt, candidate, :failed, "Could not check for existing Media: #{inspect(error)}"}
    end
  end

  defp existing_media(path) do
    case MediaDomain.list_media(
           actor: SystemActor.actor(),
           query: [filter: [path: path], limit: 1]
         ) do
      {:ok, [media]} -> {:ok, media}
      {:ok, []} -> {:ok, nil}
      {:error, error} -> {:error, error}
    end
  end
end
