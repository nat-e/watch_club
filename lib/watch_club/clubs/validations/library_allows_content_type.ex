defmodule WatchClub.Clubs.Validations.LibraryAllowsContentType do
  @moduledoc """
  Validates that a library allows the type of content being added to it.
  """
  use Ash.Resource.Validation

  require Ash.Query

  alias WatchClub.Clubs.Library
  alias WatchClub.Contents.Content

  @impl true
  def validate(%Ash.Changeset{} = changeset, _opts, context) do
    library_id = Ash.Changeset.get_argument_or_attribute(changeset, :library_id)
    content_id = Ash.Changeset.get_argument_or_attribute(changeset, :content_id)

    Library
    |> Ash.Query.for_read(:read, %{}, scope: context)
    |> Ash.Query.filter(id == ^library_id)
    |> Ash.Query.filter(exists(Content, id == ^content_id and type == parent(content_type)))
    |> Ash.exists()
    |> case do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        {:error, field: :library_id}

      {:error, error} ->
        {:error, error}
    end
  end
end
