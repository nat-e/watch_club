defmodule WatchClub.MediaSources.Import.Changes.Schedule do
  @moduledoc """
  After the `:start` transaction commits, enqueues the two Oban jobs that
  drive a Media Import to completion:

    * `SourceScanner` — walks the location and fans out one
      `CandidateIngestor` job per candidate.
    * `ImportMonitor` — the monitor. It snoozes itself until the
      scan and every candidate are done, then transitions the Media
      Import to `:completed`.

  Both jobs are tagged `media_import:<id>` so the cancel sweep catches
  them together. They are inserted in a single `OpentelemetryOban.insert_all/1` call
  to keep the after-transaction work to one SQL roundtrip; `insert_all`
  bypasses worker `unique:` config, which is fine here because the change
  runs exactly once per Media Import creation.
  """

  use Ash.Resource.Change

  alias WatchClub.MediaSources.Import.Workers.{ImportMonitor, SourceScanner}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, media_import} <- result do
        OpentelemetryOban.insert_all([
          SourceScanner.new_job(media_import),
          ImportMonitor.new_job(media_import.id)
        ])

        {:ok, media_import}
      end
    end)
  end
end
