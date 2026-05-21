defmodule WatchClub.Media.ImportPipeline.Stage do
  @moduledoc """
  Contract for an `ImportPipeline` stage.

  Each stage transforms a `Candidate` in the context of an `ImportRun` (which
  always has its `:snapshot_configuration` loaded — stages may pattern-match
  on that).

  Returns `{:ok, candidate}` to continue, or `{:halt, candidate, reason, message}`
  to short-circuit. The pipeline turns halts into the candidate's `Outcome` via
  `Candidate.set_halted_outcome/3`; stages do not construct outcomes themselves.

  `reason` is one of:

    * `:skipped` — terminal, no result row is written (e.g. existing Media,
      no refresh).
    * `:failed` — terminal, a `:failed` result row is written with `message`.
  """

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportRun

  @type halt_reason :: :skipped | :failed
  @type result ::
          {:ok, Candidate.t()}
          | {:halt, Candidate.t(), halt_reason(), String.t() | nil}

  @callback apply(Candidate.t(), ImportRun.t()) :: result()
end
