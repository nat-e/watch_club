defmodule WatchClub.Media.ImportPipeline.Stage do
  @moduledoc """
  Contract for an `ImportPipeline` stage.

  Each stage transforms a `Candidate` in the context of an `ImportRun` (which
  always has its `:snapshot_configuration` loaded — stages may pattern-match
  on that).

  Returns `{:ok, candidate}` to continue, or `{:halt, candidate, reason, message}`
  to short-circuit. On halt the pipeline finalizes the candidate via
  `Candidate.set_halted_outcome/3`. The final stage (`MatchContent`) sets the
  candidate's outcome itself for successful runs; intermediate stages do not.

  `reason` is one of:

    * `:skipped` — terminal, no result row is written (e.g. existing Media,
      no refresh).
    * `:failed` — terminal, a `:failed` result row is written with `message`.
    * `:no_match` — terminal, a `:no_match` result row is written with
      `message` (identity could not be confidently matched to Content).
  """

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportRun

  @type halt_reason :: :skipped | :failed | :no_match
  @type result ::
          {:ok, Candidate.t()}
          | {:halt, Candidate.t(), halt_reason(), String.t() | nil}

  @callback apply(Candidate.t(), ImportRun.t()) :: result()
end
