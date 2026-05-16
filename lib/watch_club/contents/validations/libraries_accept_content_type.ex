defmodule WatchClub.Contents.Validations.LibrariesAcceptContentType do
  @moduledoc """
  Validates that all selected libraries accept the content's type.
  """
  use Ash.Resource.Validation

  alias WatchClub.Clubs.Library
  alias WatchClub.Contents.Content

  @impl true
  def validate(%Ash.Changeset{data: %Content{} = content} = changeset, _opts, context) do
    library_ids = Ash.Changeset.get_argument(changeset, :library_ids)

    case selected_libraries_accept_content_type?(library_ids, content.type) do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        {:error, message: context.message || "Library does not accept this content type"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp selected_libraries_accept_content_type?(nil, _content_type), do: {:ok, true}
  defp selected_libraries_accept_content_type?([], _content_type), do: {:ok, true}

  defp selected_libraries_accept_content_type?(library_ids, content_type) do
    unique_library_ids = Enum.uniq(library_ids)

    Library
    |> Ash.Query.filter(id in ^unique_library_ids)
    |> Ash.Query.filter(^content_type in accepted_content_types)
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, accepted_count} -> {:ok, accepted_count == length(unique_library_ids)}
      {:error, error} -> {:error, error}
    end
  end
end
