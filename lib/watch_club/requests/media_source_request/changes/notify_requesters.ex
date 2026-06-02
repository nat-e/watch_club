defmodule WatchClub.Requests.MediaSourceRequest.Changes.NotifyRequesters do
  @moduledoc """
  After a Media Source Request write commits, tells every user who has a
  `ContentRequest` for the same content that their request may have moved: a
  request's status/progress is *derived* from MSR state, so a change here can
  shift it without ever touching the ContentRequest row.

  Broadcasts `{:request_changed, content_request_id}` to each requester's
  `content_requests:user:<user_id>` topic — the topic the My Requests page
  listens on. Runs in `after_transaction` so subscribers re-read *committed*
  state, not the in-flight changeset.
  """
  use Ash.Resource.Change

  alias WatchClub.SystemActor
  alias WatchClub.Requests

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, media_source_request} <- result do
        notify_requesters(media_source_request.content_id)
      end

      result
    end)
  end

  defp notify_requesters(content_id) do
    content_id
    |> Requests.list_content_requests_for_content!(actor: SystemActor.actor())
    |> Enum.each(fn content_request ->
      Phoenix.PubSub.broadcast(
        WatchClub.PubSub,
        "content_requests:user:#{content_request.user_id}",
        {:request_changed, content_request.id}
      )
    end)
  end
end
