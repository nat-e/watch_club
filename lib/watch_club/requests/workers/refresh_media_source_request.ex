defmodule WatchClub.Requests.Workers.RefreshMediaSourceRequest do
  @moduledoc """
  Reconciles one `MediaSourceRequest` against its *arr's current truth. The
  webhook handler enqueues one of these (after confirming the request exists)
  for any event carrying a resource id; a future poller would enqueue the
  same job. Runs `refresh_status`, which re-derives the state.

  Every webhook enqueues its own reconcile — the refresh is idempotent and
  cheap, so duplicates from a webhook burst are harmless.
  """
  use Oban.Worker,
    queue: :media_source_requests,
    max_attempts: 5

  alias WatchClub.Requests
  alias WatchClub.Requests.MediaSourceRequest
  alias WatchClub.SystemActor

  require Logger

  @doc "Builds a reconcile job for one Media Source Request."
  def new_job(media_source_request_id) do
    new(%{media_source_request_id: media_source_request_id})
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_source_request_id" => id}}) do
    actor = SystemActor.actor()

    case Requests.get_media_source_request_by_id(id, actor: actor) do
      {:ok, %MediaSourceRequest{} = request} ->
        Requests.refresh_media_source_request!(request, actor: actor)
        :ok

      other ->
        # The webhook only enqueues for requests that existed moments ago, so a
        # miss here is an anomaly (deleted mid-flight, or a bug) — surface it.
        Logger.error("RefreshMediaSourceRequest: request #{id} not found (#{inspect(other)})")
        :ok
    end
  end
end
