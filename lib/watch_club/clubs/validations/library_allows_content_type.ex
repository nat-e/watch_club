defmodule WatchClub.Clubs.Validations.LibraryAllowsContentType do
  @moduledoc """
  Validates that the library accepts the content's type. A Library holds a single
  `content_type`, so the Content being added must match it.
  """
  use Ash.Resource.Validation

  alias WatchClub.Clubs.Library
  alias WatchClub.Contents.Content

  @impl true
  def validate(%Ash.Changeset{} = changeset, _opts, _context) do
    library_id = Ash.Changeset.get_argument_or_attribute(changeset, :library_id)
    content_id = Ash.Changeset.get_argument_or_attribute(changeset, :content_id)

    with {:ok, %Library{content_type: library_type}} <-
           Ash.get(Library, library_id, authorize?: false),
         {:ok, %Content{type: content_type}} <- Ash.get(Content, content_id, authorize?: false) do
      if library_type == content_type, do: :ok, else: {:error, field: :library_id}
    end
  end
end
