defmodule WatchClub.Media.ImportPipeline.Stage do
  @moduledoc """
  Contract for an `ImportPipeline` stage.

  Each stage transforms a `Candidate` in the context of an `ImportRun` (which
  always has its `:snapshot_configuration` loaded — stages may pattern-match
  on that).

  Returns `{:ok, candidate}` to continue, or `{:halt, reason}` to
  short-circuit the pipeline for this candidate.
  """

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportRun

  @type result :: {:ok, Candidate.t()} | {:halt, term()}

  @callback apply(Candidate.t(), ImportRun.t()) :: result()
end
