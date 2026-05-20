defmodule WatchClub.Media.Importer.ExistingMediaGate do
  @moduledoc false

  alias WatchClub.Media, as: MediaDomain
  alias WatchClub.Media.Importer.MediaCandidate
  alias WatchClub.Media.Media
  alias WatchClub.Media.MediaImport
  alias WatchClub.SystemActor

  def apply(%MediaCandidate{} = candidate, %MediaImport{refresh_metadata?: refresh_metadata?}) do
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
