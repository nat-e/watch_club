defmodule WatchClub.Requests.ContentRequest.Changes.CreateMediaSourceRequests do
  @moduledoc """
  After a Content Request is created, enqueues (in a single `insert_all`)
  one submit job per request-capable `Source` that can serve the content —
  every same-type source (two radarrs each) and every Media Type the content
  maps to (a book fans out to ebook *and* audiobook sources). Nothing is
  written to `media_source_requests` here: the worker creates each row only
  after its add/adopt succeeds.

  Creation-time only — there is no backfill. A source connected later does
  nothing for an existing request.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.ContentType
  alias WatchClub.MediaSources
  alias WatchClub.Requests.Workers.SubmitMediaSourceRequest
  alias WatchClub.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    content_type = Ash.Changeset.get_argument(changeset, :content_type)

    Ash.Changeset.after_action(changeset, fn _changeset, content_request ->
      content_type
      |> ContentType.media_types()
      |> MediaSources.list_request_capable_sources!(actor: SystemActor.actor())
      |> Enum.map(&SubmitMediaSourceRequest.new_job(content_request.content_id, &1.id))
      |> Oban.insert_all()

      {:ok, content_request}
    end)
  end
end
