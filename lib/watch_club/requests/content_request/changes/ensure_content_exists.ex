defmodule WatchClub.Requests.ContentRequest.Changes.EnsureContentExists do
  @moduledoc """
  Resolves the `:request` action's `(external_id_source, external_id,
  content_type)` arguments into a real `Content`, creating it from the
  Metadata Provider if it does not exist yet, and sets `content_id` on the
  changeset before the upsert. Mirrors how Add to Library may create missing
  Content.

  Runs `before_action` so `content_id` is present for the
  `unique_user_content` upsert identity.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      external_id_source = Ash.Changeset.get_argument(changeset, :external_id_source)
      external_id = Ash.Changeset.get_argument(changeset, :external_id)
      content_type = Ash.Changeset.get_argument(changeset, :content_type)

      with {:ok, content} <-
             ensure_content(external_id_source, content_type, external_id, context.actor) do
        Ash.Changeset.force_change_attribute(changeset, :content_id, content.id)
      else
        {:error, reason} ->
          Ash.Changeset.add_error(changeset,
            field: :external_id,
            message: "could not resolve content: #{inspect(reason)}"
          )
      end
    end)
  end

  defp ensure_content(:tmdb, :movie, external_id, actor) do
    with {tmdb_id, ""} <- Integer.parse(external_id) do
      Contents.get_or_create_movie(tmdb_id, actor)
    else
      _ -> {:error, :invalid_external_id}
    end
  end

  defp ensure_content(:tmdb, :tv_show, external_id, actor) do
    with {tmdb_id, ""} <- Integer.parse(external_id) do
      Contents.get_or_create_tv_show(tmdb_id, actor)
    else
      _ -> {:error, :invalid_external_id}
    end
  end

  defp ensure_content(provider, content_type, _external_id, _actor) do
    {:error, {:unsupported, provider, content_type}}
  end
end
