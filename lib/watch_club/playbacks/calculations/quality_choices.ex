defmodule WatchClub.Playbacks.Calculations.QualityChoices do
  @moduledoc """
  The Qualities of a Playback's Video, by their ids, best first, and the one it plays: its
  Playback Session's Quality when the Video has it, else nil for Auto.
  """
  use Ash.Resource.Calculation

  alias WatchClub.Playbacks.Playback.QualityLadder

  @type t :: %__MODULE__{choices: [String.t()], picked: String.t() | nil}

  defstruct choices: [], picked: nil

  @impl true
  def load(_query, _opts, _context), do: [:session, media: [video: :default_video_track]]

  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(playbacks, _opts, _context) do
    Enum.map(playbacks, fn %{media: %{video: video}, session: session} ->
      choices = QualityLadder.ids(video)
      %__MODULE__{choices: choices, picked: if(session.quality in choices, do: session.quality)}
    end)
  end
end
