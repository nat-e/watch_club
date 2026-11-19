defmodule WatchClub.MediaSources.Import.Workers.StartScheduledImports do
  @moduledoc """
  Starts the scheduled Media Imports, which catch the files of lost webhooks. Runs every 15
  minutes (see `config/config.exs`). A failed run isn't retried: the next scheduled run takes its
  place.
  """
  use Oban.Worker, queue: :scheduled_media_imports, max_attempts: 1

  alias WatchClub.MediaSources
  alias WatchClub.SystemActor

  @impl Oban.Worker
  def perform(_job) do
    MediaSources.start_scheduled_media_imports!(actor: SystemActor.actor())
  end
end
