defmodule WatchClub.Media.Calculations.MediaImportConfigurationName do
  use Ash.Resource.Calculation

  alias WatchClub.Contents.ContentType
  alias WatchClub.Media.MediaType

  @impl true
  def load(_query, _opts, _context) do
    [:content_type, :media_type, :source_type, :filesystem_path]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      "#{ContentType.translated_label(record.content_type)} #{MediaType.translated_label(record.media_type)} #{label(record.source_type)}: #{record.filesystem_path}"
    end)
  end

  defp label(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
