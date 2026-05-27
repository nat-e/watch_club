defmodule WatchClub.Media.MediaSource.Calculations.GetImplementation do
  @moduledoc """
  Returns the per-type implementation row attached to a `MediaSource`.

  Mirrors `WatchClub.Contents.Calculations.GetContentImplementation`.
  Always present after the resource is loaded: every persisted
  `MediaSource` has exactly one implementation matching its `source_type`.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_, _, _), do: [:filesystem, :radarr]

  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(records, _, _) do
    Enum.map(records, fn record ->
      cond do
        record.filesystem -> record.filesystem
        record.radarr -> record.radarr
        true -> raise "Media Source #{record.id} has no implementation"
      end
    end)
  end
end
