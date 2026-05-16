defmodule WatchClub.Clubs.Validations.UniqueAcceptedContentTypes do
  @moduledoc """
  Validates that a library's accepted content types do not contain duplicates.
  """
  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute

  @impl true
  def validate(%Ash.Changeset{} = changeset, _opts, context) do
    accepted_content_types = Ash.Changeset.get_attribute(changeset, :accepted_content_types)

    if duplicate_content_types?(accepted_content_types) do
      {:error,
       InvalidAttribute.exception(
         field: :accepted_content_types,
         message: context.message || "Library accepted content types must be unique",
         value: accepted_content_types
       )}
    else
      :ok
    end
  end

  @impl true
  def atomic(_changeset, _opts, context) do
    accepted_content_types = expr(^atomic_ref(:accepted_content_types))

    {:atomic, [:accepted_content_types],
     expr(
       fragment(
         "cardinality(?) <> cardinality(ARRAY(SELECT DISTINCT unnest(?)))",
         ^accepted_content_types,
         ^accepted_content_types
       )
     ),
     expr(
       error(^InvalidAttribute, %{
         field: :accepted_content_types,
         message: ^(context.message || "Library accepted content types must be unique"),
         value: ^accepted_content_types
       })
     )}
  end

  defp duplicate_content_types?(accepted_content_types) when is_list(accepted_content_types) do
    length(Enum.uniq(accepted_content_types)) != length(accepted_content_types)
  end

  defp duplicate_content_types?(_accepted_content_types), do: false
end
