defmodule WatchClub.Contents.Calculations.ActorVideoToPlay do
  @moduledoc """
  The file Play opens for the actor, among the `videos_to_play` of a Movie, TV Show Episode or
  Sports Event: the one holding the Part they stopped in, else the first. Nil without Media.
  """
  use Ash.Resource.Calculation

  alias WatchClub.MediaCatalog.Part

  @impl true
  def load(_query, _opts, _context), do: [:videos_to_play, :actor_progress]

  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      part_number =
        case record.actor_progress do
          %{completed: false, part_number: number} -> number
          _not_started_or_finished -> nil
        end

      Enum.find(record.videos_to_play, List.first(record.videos_to_play), fn video ->
        Enum.any?(video.parts, &(Part.work_id(&1) == record.id and &1.number == part_number))
      end)
    end)
  end
end
