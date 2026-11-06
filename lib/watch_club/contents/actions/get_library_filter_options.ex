defmodule WatchClub.Contents.Actions.GetLibraryFilterOptions do
  @moduledoc """
  The decades and original languages of the Library's Content: the decades newest first, and the
  languages most common first.
  """
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Contents.Content

  @impl true
  def run(_input, _opts, context) do
    opts = Ash.Context.to_opts(context)
    library = Ash.Query.for_read(Content, :in_library, %{}, opts)

    with {:ok, decades} <- Ash.list(library, :decade, [uniq?: true] ++ opts),
         {:ok, languages} <- Ash.list(library, :original_language, opts) do
      {:ok,
       %{
         decades: Enum.sort(decades, :desc),
         original_languages:
           languages
           |> Enum.frequencies()
           |> Enum.sort_by(fn {language, count} -> {-count, language} end)
           |> Enum.map(fn {language, _count} -> language end)
       }}
    end
  end
end
