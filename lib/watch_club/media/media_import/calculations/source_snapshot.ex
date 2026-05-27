defmodule WatchClub.Media.MediaImport.Calculations.SourceSnapshot do
  @moduledoc """
  Rebuilds the `MediaSource` struct that was active when a `MediaImport`
  was started, using the snapshot stored on the Media Import.

  The snapshot is the source of truth during execution: an admin can edit
  the live `:media_source` relationship after the Media Import is scheduled,
  and it still processes the original values. Pairs with
  `WatchClub.Media.MediaImport.Changes.SnapshotMediaSource`, which writes
  the snapshot at Media Import creation time.
  """

  use Ash.Resource.Calculation

  alias WatchClub.Media.MediaSource

  @impl true
  def load(_query, _opts, _context), do: [:media_source_snapshot]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &decode/1)
  end

  defp decode(%{media_source_snapshot: snapshot}) do
    %MediaSource{
      id: Map.fetch!(snapshot, "id"),
      source_type: snapshot_atom(snapshot, "source_type"),
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
