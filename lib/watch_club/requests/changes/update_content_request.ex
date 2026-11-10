defmodule WatchClub.Requests.Changes.UpdateContentRequest do
  @moduledoc """
  Updates the Content's ContentRequest, if it has one, when its dependencies have changed, and
  completes it once every aired part of its Content has Media.
  This is called when:
  - A MediaSourceRequest has been created/updated/destroyed for this Content
  - A Media has been created/matched/destroyed for this Content

  This will trigger Pubsub notifications to be sent.
  We try to not spam by only detecting if the ContentRequest derived status will be impacted.

  In most cases, this won't update anything besides the `updated_at` field of the request but this
  is still necessary to:
  - re-order the most recently updated requests
  - trigger pubsub notifications when dependencies have changed
  """
  use Ash.Resource.Change

  alias WatchClub.MediaCatalog.Media
  alias WatchClub.Requests.{ContentRequest, MediaSourceRequest}
  alias WatchClub.SystemActor

  @impl true
  # When a Media has been created or matched, update the content request.
  # Re-importing or matching a file can attach it to another Content than before, so the request
  # of the previous Content is updated too. Unmatched Media have no Content.
  def change(%Ash.Changeset{resource: Media, action_type: type} = changeset, _opts, _context)
      when type in [:create, :update] do
    changeset
    |> Ash.Changeset.before_action(
      &Ash.Changeset.put_context(&1, :previous_content_id, previous_content_id(&1))
    )
    |> Ash.Changeset.after_action(fn changeset, %Media{content_id: content_id} = updated_media ->
      [changeset.context.previous_content_id, content_id]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.each(&update_content_request(&1, %{}))

      if content_id, do: complete_content_request!(content_id)

      {:ok, updated_media}
    end)
  end

  # When a media has been deleted, update the content request.
  # Unmatched Media have no Content.
  def change(%Ash.Changeset{resource: Media, action_type: :destroy} = changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn
      _changeset, %Media{content_id: nil} = destroyed_media ->
        {:ok, destroyed_media}

      _changeset, %Media{content_id: content_id} = destroyed_media ->
        update_content_request(content_id, %{})

        {:ok, destroyed_media}
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

      # 3 scenarios in which we refresh the ContentRequest:
      # - The MSR has been deleted (re-point to the remaining best, or nil)
      # - The best MSR has just been created
      # - The best MSR status / progress changed
      #
      # We don't support the case where the MSR got downgraded to not being the best
      # one anymore. But this is so niche that it doesn't justify the extra query
      # (we would have to check the original best MSR in a before_action and compare).
      if changeset.action_type == :destroy or (is_best_msr? and changed?) do
        update_content_request(content_id, %{
          best_source_request_id: (best_msr && best_msr.id) || nil
        })
      end

      {:ok, updated_msr}
    end)
  end

  # The Content the Media had before: on a create, the one of the Media the upsert updates
  defp previous_content_id(%Ash.Changeset{action_type: :create} = changeset) do
    media_source_id = Ash.Changeset.get_attribute(changeset, :media_source_id)
    path = Ash.Changeset.get_attribute(changeset, :path)

    previous_media =
      Media
      |> Ash.Query.filter(media_source_id == ^media_source_id and path == ^path)
      |> Ash.read_one!(authorize?: false)

    previous_media && previous_media.content_id
  end

  defp previous_content_id(%Ash.Changeset{action_type: :update, data: media}),
    do: media.content_id

  def update_content_request(content_id, input) do
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

  # Only a new or matched Media can complete it
  defp complete_content_request!(content_id) do
    ContentRequest
    |> Ash.Query.filter(content_id == ^content_id)
    |> Ash.bulk_update!(:complete, %{},
      notify?: true,
      actor: SystemActor.actor(),
      authorize?: false
    )
  end
end
