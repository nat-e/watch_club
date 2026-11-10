defmodule WatchClub.Contents.Actions.GetLibraryFilterOptions do
  @moduledoc """
  The genres, decades and original languages of the Library's Content: the decades newest first,
  and the genres and languages most common first.
  """
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Contents.Content

  @impl true
  def run(_input, _opts, context) do
    opts = Ash.Context.to_opts(context)
    library = Ash.Query.for_read(Content, :in_library, %{}, opts)

    with {:ok, genres} <- Ash.list(library, :genres, opts),
         {:ok, decades} <- Ash.list(library, :decade, [uniq?: true] ++ opts),
         {:ok, languages} <- Ash.list(library, :original_language, opts) do
      {:ok,
       %{
         genres: genres |> Enum.concat() |> most_common_first(),
         decades: Enum.sort(decades, :desc),
         # Sports Events have no original language
         original_languages: languages |> Enum.reject(&is_nil/1) |> most_common_first()
       }}
    end
  end

  defp most_common_first(values) do
    values
    |> Enum.frequencies()
    |> Enum.sort_by(fn {value, count} -> {-count, value} end)
    |> Enum.map(fn {value, _count} -> value end)
  end
end
