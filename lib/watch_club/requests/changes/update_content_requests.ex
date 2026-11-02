defmodule WatchClub.Requests.Changes.UpdateContentRequests do
  @moduledoc """
  Updates all the ContentRequests for a Content when their dependencies have changed.
  This is called when:
  - A MediaSourceRequest has been created/updated/destroyed for this Content
  - A Media has been created/destroyed for this Content

  This will trigger Pubsub notifications to be sent.
  We try to not spam by only detecting if the ContentRequest derived status will be impacted.

  In most cases, this won't update anything besides the `updated_at` field of the requests but this
  is still necessary to:
  - re-order the most recently updated requests
  - trigger pubsub notifications when dependencies have changed
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.Content
  alias WatchClub.MediaCatalog.Media
  alias WatchClub.Requests.{ContentRequest, MediaSourceRequest}
  alias WatchClub.SystemActor

  @impl true
  # When a media has been created or deleted, update the content request.
  def change(%Ash.Changeset{resource: Media, action_type: :destroy} = changeset, _opts, _context) do
    # Ash loads the Content before deleting the Media. It can't be loaded after: the delete
    # cascades to the Video, Ebook or Audiobook row that links the Media to its Content.
    changeset
    |> Ash.Changeset.load(:content)
    |> Ash.Changeset.after_action(fn _changeset, %Media{content: content} = destroyed_media ->
      update_media_content_requests(content)

      {:ok, destroyed_media}
    end)
  end

  def change(%Ash.Changeset{resource: Media} = changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, %Media{} = updated_media ->
      %Media{content: content} = Ash.load!(updated_media, :content, authorize?: false)
      update_media_content_requests(content)

      {:ok, updated_media}
    end)
  end

  # When a MediaSourceRequest has been created, updated or deleted, update the content request
  # To avoid spamming, we only update if Content Request status or progress will be impacted
  def change(%Ash.Changeset{resource: MediaSourceRequest} = changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, %MediaSourceRequest{} = updated_msr ->
      content_id = updated_msr.content_id
      updated_status = updated_msr.status
      updated_progress = updated_msr.download_progress
      original_status = Ash.Changeset.get_data(changeset, :status)
      original_progress = Ash.Changeset.get_data(changeset, :download_progress)

      best_msr =
        MediaSourceRequest
        |> Ash.Query.filter(content_id == ^content_id)
        |> Ash.Query.sort(status_rank: :desc, download_progress: :desc)
        |> Ash.read_first!(authorize?: false, actor: SystemActor.actor())

      is_best_msr? = best_msr && best_msr.media_source_id == updated_msr.media_source_id

      # On create, `original_*` are the attribute defaults, so a freshly-submitted
      # (still :searching) MSR looks unchanged. Treat creation as a change so the
      # ContentRequest links to its new best MSR right away.
      changed? =
        changeset.action_type == :create or
          updated_status != original_status or updated_progress != original_progress

      # 3 scenarios in which we refresh the ContentRequests:
      # - The MSR has been deleted (re-point to the remaining best, or nil)
      # - The best MSR has just been created
      # - The best MSR status / progress changed
      #
      # We don't support the case where the MSR got downgraded to not being the best
      # one anymore. But this is so niche that it doesn't justify the extra query
      # (we would have to check the original best MSR in a before_action and compare).
      if changeset.action_type == :destroy or (is_best_msr? and changed?) do
        update_content_requests(content_id, %{
          best_source_request_id: (best_msr && best_msr.id) || nil
        })
      end

      {:ok, updated_msr}
    end)
  end

  def update_content_requests(content_id, input) do
    ContentRequest
    |> Ash.Query.filter(content_id == ^content_id)
    |> Ash.bulk_update(
      :update,
      input,
      notify?: true,
      actor: SystemActor.actor(),
      authorize?: false
    )
  end

  # Un-matched Media have no Content, so there are no requests to update
  defp update_media_content_requests(nil), do: :ok

  defp update_media_content_requests(%Content{id: content_id}),
    do: update_content_requests(content_id, %{})
end
