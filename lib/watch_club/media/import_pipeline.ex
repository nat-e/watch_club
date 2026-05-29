defmodule WatchClub.Media.ImportPipeline do
  @moduledoc """
  Behaviour for media import pipelines.

  Split in two so the workers can fan out: `scan/1` produces the candidate
  enumerable for a `MediaImport` and `process_candidate/2` runs the
  per-file stages. `ScanMediaSource` calls `scan/1` and enqueues one
  `ImportMediaFile` job per candidate; each `ImportMediaFile` calls
  `process_candidate/2`.
  """

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.MediaImport

  @filesystem_pipeline Application.compile_env(
                         :watch_club,
                         :import_pipeline_filesystem,
                         WatchClub.Media.FilesystemImportPipeline
                       )

  @callback scan(MediaImport.t()) :: {:ok, Enumerable.t(Candidate.t())} | {:error, term()}

  @callback process_candidate(Candidate.t(), MediaImport.t()) ::
              :ok | {:halt, term()} | {:error, term()}

  @doc """
  Returns the pipeline module for a given Media Source type. Test overrides
  go through `:watch_club, :import_pipeline_filesystem`.
  """
  def for_source_type(:filesystem), do: @filesystem_pipeline
end
