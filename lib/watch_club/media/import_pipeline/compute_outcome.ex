defmodule WatchClub.Media.ImportPipeline.ComputeOutcome do
  @moduledoc """
  Terminal pipeline stage. Decides the `Outcome` for a candidate that made it
  through every earlier stage without error.

  Until matching lands (5b/5c), every probed candidate is by definition a
  no-match: we have its identity hints and its media structure, but no logic
  to resolve them to a `Content` row.
  """

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Candidate.Outcome

  @stage "content_matching"

  def apply(%Candidate{} = candidate, _configuration) do
    outcome = %Outcome{
      status: :no_match,
      message: "Could not confidently match file to Content or TV Show Episode",
      metadata: %{stage: @stage}
    }

    {:ok, %{candidate | outcome: outcome}}
  end
end
