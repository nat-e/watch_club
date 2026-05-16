defmodule WatchClub.Contents.Changes.SetLibraries do
  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, _opts, context) do
    library_ids = Ash.Changeset.get_argument(changeset, :library_ids)
    Logger.info("Setting content to club libraries: #{inspect(library_ids)}")

    Ash.Changeset.after_action(changeset, fn _changeset, content ->
      content
      |> Ash.Changeset.for_update(:set_libraries, %{library_ids: library_ids}, scope: context)
      |> Ash.update()
      |> case do
        {:ok, updated_content} -> {:ok, updated_content}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
