defmodule WatchClub.Media.ImportPipeline.FilterExisting do
  @moduledoc """
  Decides whether a candidate continues through the pipeline based on whether
  Media already exists at its path.

    * No existing Media → continue.
    * Existing Media and refresh on → continue, tagged for refresh via
      `:existing_media`.
    * Existing Media and refresh off → `:skip` (no Outcome row, per
      `CONTEXT.md`: existing media skipped without refresh produces no result).
    * Lookup error → fail the candidate.
  """

  alias WatchClub.Media, as: MediaDomain
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.Outcome
  alias WatchClub.Media.ImportRun
  alias WatchClub.Media.Media
  alias WatchClub.SystemActor

  @stage "filter_existing"

  def apply(%Candidate{} = candidate, %ImportRun{refresh_metadata?: refresh_metadata?}) do
    case existing_media(candidate.path) do
      {:ok, nil} ->
        {:ok, candidate}

      {:ok, %Media{id: id, type: type}} when refresh_metadata? ->
        {:ok, %{candidate | existing_media: %{id: id, type: type}}}

      {:ok, %Media{}} ->
        :skip

      {:error, error} ->
        {:error, fail(candidate, error)}
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

  defp fail(candidate, error) do
    %{
      candidate
      | outcome: %Outcome{
          status: :failed,
          message: "Could not check for existing Media: #{inspect(error)}",
          metadata: %{stage: @stage}
        }
    }
  end
end
