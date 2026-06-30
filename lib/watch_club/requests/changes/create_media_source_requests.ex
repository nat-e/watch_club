defmodule WatchClub.Requests.Changes.CreateMediaSourceRequests do
  @moduledoc """
  Enqueues Oban jobs to submit requests for a Content with all eligible Media Sources.
  Called when a Content has been requested by a User.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.ContentType
  alias WatchClub.MediaSources
  alias WatchClub.Requests.Workers.SubmitMediaSourceRequest

  @impl true
  def change(changeset, _opts, _context) do
    content_identity = Ash.Changeset.get_argument(changeset, :content_identity)

    Ash.Changeset.after_action(changeset, fn _changeset, content_request ->
      content_identity.type
      |> ContentType.media_types()
      |> MediaSources.list_request_capable_sources!(authorize?: false)
      |> Enum.map(&SubmitMediaSourceRequest.new_job(content_request.content_id, &1.id))
      |> Oban.insert_all()

      {:ok, content_request}
    end)
  end
end
