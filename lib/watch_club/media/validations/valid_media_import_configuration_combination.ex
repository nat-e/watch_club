defmodule WatchClub.Media.Validations.ValidMediaImportConfigurationCombination do
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    content_type = attribute_or_data(changeset, :content_type)
    media_type = attribute_or_data(changeset, :media_type)

    if valid_combination?(content_type, media_type) do
      :ok
    else
      {:error, field: :media_type, message: "is not valid for this Content Type"}
    end
  end

  defp attribute_or_data(changeset, attribute) do
    case Ash.Changeset.get_attribute(changeset, attribute) do
      nil -> Map.get(changeset.data, attribute)
      value -> value
    end
  end

  defp valid_combination?(:movie, :video), do: true
  defp valid_combination?(:tv_show, :video), do: true
  defp valid_combination?(:book, :ebook), do: true
  defp valid_combination?(:book, :audiobook), do: true
  defp valid_combination?(_content_type, _media_type), do: false
end
