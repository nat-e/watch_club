defmodule WatchClub.Media.Changes.ProcessMediaImport do
  use Ash.Resource.Change

  alias WatchClub.Media, as: MediaDomain
  alias WatchClub.Media.MediaImport

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_transaction(changeset, after_transaction(context.actor))
  end

  defp after_transaction(actor) do
    fn changeset, result ->
      case result do
        {:ok, %MediaImport{} = media_import} ->
          process_and_mark_completed(media_import, actor)

        {:error, error} ->
          changeset.data
          |> mark_failed(actor)
          |> case do
            {:ok, _media_import} -> {:error, error}
            {:error, mark_failed_error} -> {:error, mark_failed_error}
          end
      end
    end
  end

  defp process_and_mark_completed(media_import, actor) do
    try do
      :ok = process(media_import)

      media_import
      |> mark_completed(actor)
      |> case do
        {:ok, completed_import} ->
          {:ok, completed_import}

        {:error, error} ->
          mark_failed_after_error(media_import, actor, error)
      end
    rescue
      error ->
        mark_failed_after_error(media_import, actor, error)
    end
  end

  defp process(%MediaImport{}), do: :ok

  defp mark_failed_after_error(media_import, actor, error) do
    media_import
    |> mark_failed(actor)
    |> case do
      {:ok, _media_import} -> {:error, error}
      {:error, mark_failed_error} -> {:error, mark_failed_error}
    end
  end

  defp mark_completed(media_import, actor) do
    MediaDomain.mark_media_import_completed(media_import, actor: actor)
  end

  defp mark_failed(media_import, actor) do
    MediaDomain.mark_media_import_failed(media_import, actor: actor)
  end
end
