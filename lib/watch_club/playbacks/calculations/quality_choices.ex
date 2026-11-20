defmodule WatchClub.Playbacks.Calculations.QualityChoices do
  @moduledoc """
  The Qualities of a Playback's Video, best first, by the id of their HLS variant and their
  label, and the one it plays: its Playback Session's Quality when the Video has a Quality with
  that label, else nil for Auto.
  """
  use Ash.Resource.Calculation

  alias WatchClub.Playbacks.Playback.QualityLadder

  @type choice :: %{id: String.t(), label: String.t()}
  @type t :: %__MODULE__{choices: [choice()], picked: choice() | nil}

  defstruct choices: [], picked: nil

  @impl true
  def load(_query, _opts, _context), do: [:session, media: [video: :default_video_track]]

  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(playbacks, _opts, _context) do
    Enum.map(playbacks, fn %{media: %{video: video}, session: session} ->
      choices = QualityLadder.labels(video)
      %__MODULE__{choices: choices, picked: Enum.find(choices, &(&1.label == session.quality))}
    end)
  end
end
