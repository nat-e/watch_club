defmodule WatchClub.Media.ImportRun.Calculations.SnapshotConfiguration do
  @moduledoc """
  Rebuilds the `ImportConfiguration` struct that was active when an `ImportRun`
  was started, using the snapshot stored on the run.

  The snapshot is the source of truth during execution: an admin can edit the
  live `:configuration` relationship after the run is scheduled, and the run
  still processes the original values. Pairs with
  `WatchClub.Media.ImportRun.Changes.SnapshotConfiguration`, which writes the
  snapshot at run creation time.
  """

  use Ash.Resource.Calculation

  alias WatchClub.Media.ImportConfiguration

  @impl true
  def load(_query, _opts, _context), do: [:configuration_snapshot]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &decode/1)
  end

  defp decode(%{configuration_snapshot: snapshot}) do
    %ImportConfiguration{
      id: Map.fetch!(snapshot, "id"),
      source_type: snapshot_atom(snapshot, "source_type"),
      content_type: snapshot_atom(snapshot, "content_type"),
      media_type: snapshot_atom(snapshot, "media_type"),
      filesystem_path: Map.fetch!(snapshot, "filesystem_path")
    }
  end

  defp snapshot_atom(snapshot, key) do
    snapshot
    |> Map.fetch!(key)
    |> String.to_existing_atom()
  end
end
