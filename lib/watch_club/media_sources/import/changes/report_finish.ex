defmodule WatchClub.MediaSources.Import.Changes.ReportFinish do
  @moduledoc """
  Emits `[:watch_club, :media_import, :finish]` once a Media Import ends, with its duration in
  microseconds and its final status.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, media_import ->
      :telemetry.execute(
        [:watch_club, :media_import, :finish],
        %{
          duration:
            DateTime.diff(media_import.finished_at, media_import.inserted_at, :microsecond)
        },
        %{status: media_import.status}
      )

      {:ok, media_import}
    end)
  end

  @impl true
  def atomic(changeset, opts, context), do: {:ok, change(changeset, opts, context)}
end
