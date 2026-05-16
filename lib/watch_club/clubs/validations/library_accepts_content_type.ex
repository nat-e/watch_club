defmodule WatchClub.Clubs.Validations.LibraryAcceptsContentType do
  @moduledoc """
  Validates that a library accepts the type of content being added to it.
  """
  use Ash.Resource.Validation

  alias WatchClub.Clubs.Library
  alias WatchClub.Contents.Content

  @impl true
  def validate(%Ash.Changeset{} = changeset, _opts, context) do
    library_id = Ash.Changeset.get_argument_or_attribute(changeset, :library_id)
    content_id = Ash.Changeset.get_argument_or_attribute(changeset, :content_id)

    case library_accepts_content_type?(library_id, content_id) do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        {:error,
         field: :library_id,
         message: context.message || "Library does not accept this content type"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp library_accepts_content_type?(nil, _content_id), do: {:ok, true}
  defp library_accepts_content_type?(_library_id, nil), do: {:ok, true}

  defp library_accepts_content_type?(library_id, content_id) do
    Library
    |> Ash.Query.for_read(:read, %{}, authorize?: false)
    |> Ash.Query.filter(id == ^library_id)
    |> Ash.Query.filter(
      exists(Content, id == ^content_id and type in parent(accepted_content_types))
    )
    |> Ash.exists()
  end
end
