defmodule WatchClub.Media.ImportPipeline.FilterExisting do
  @moduledoc false

  alias WatchClub.Media, as: MediaDomain
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportRun
  alias WatchClub.Media.Media
  alias WatchClub.SystemActor

  def apply(%Candidate{} = candidate, %ImportRun{refresh_metadata?: refresh_metadata?}) do
    case existing_media(candidate.path) do
      {:ok, nil} ->
        {:ok, candidate}

      {:ok, %Media{id: id, type: type}} when refresh_metadata? ->
        {:ok, %{candidate | existing_media: %{id: id, type: type}}}

      {:ok, %Media{}} ->
        :skip

      {:error, error} ->
        {:error, error}
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
