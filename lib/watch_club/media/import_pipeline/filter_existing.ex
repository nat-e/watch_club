defmodule WatchClub.Media.ImportPipeline.FilterExisting do
  @moduledoc """
  Decides whether a candidate continues through the pipeline based on whether
  it has a pre-loaded `existing_media` and whether the run requests a refresh.

    * No existing Media → continue.
    * Existing Media and refresh on → continue.
    * Existing Media and refresh off → halt as `:skipped`.

  The `existing_media` field is populated by the pipeline before this stage
  runs; this stage performs no I/O.
  """

  @behaviour WatchClub.Media.ImportPipeline.Stage

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportRun

  @impl true
  def apply(%Candidate{existing_media: nil} = candidate, %ImportRun{}),
    do: {:ok, candidate}

  def apply(%Candidate{} = candidate, %ImportRun{refresh_metadata?: true}),
    do: {:ok, candidate}

  def apply(%Candidate{} = candidate, %ImportRun{refresh_metadata?: false}),
    do: {:halt, candidate, :skipped, nil}
end
