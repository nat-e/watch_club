defmodule WatchClub.Contents.Actions.SearchContent do
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias WatchClub.Contents.{Content, ContentView}
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Integrations.Tmdb.{MovieSearchResult, TvSearchResult}

  @impl true
  def run(
        %Ash.ActionInput{arguments: %{query: query, content_type: :movies_and_shows}},
        _opts,
        %Ash.Resource.Actions.Implementation.Context{actor: actor}
      ) do
    with {:ok, response} <- Tmdb.search_multi(query, locale: actor.settings.locale),
         results <-
           Enum.filter(response.results, fn res ->
             is_struct(res, MovieSearchResult) || is_struct(res, TvSearchResult)
           end),
         {:ok, contents} <- get_contents_by_external_id(:movies_and_shows, results, actor),
         contents_by_external_id <-
           Map.new(contents, fn content -> {content.external_id, content} end) do
      {:ok,
       results
       |> Enum.map(fn res -> to_content_view(res, Map.get(contents_by_external_id, res.id)) end)}
    end
  end

  def run(
        %Ash.ActionInput{arguments: %{content_type: :books}},
        _opts,
        _context
      ) do
    {:ok, []}
  end

  defp get_contents_by_external_id(:movies_and_shows, results, user) do
    external_ids = results |> Enum.map(fn r -> r.id end)

    Content
    |> Ash.Query.filter(external_id_source == :tmdb and external_id in ^external_ids)
    |> Ash.read(action: :for_view, actor: user)
  end

  defp to_content_view(%MovieSearchResult{} = result, content) do
    ContentView.new!(%{
      external_id_source: :tmdb,
      external_id: Integer.to_string(result.id),
      type: :movie,
      content: content,
      title: result.title,
      description: result.overview,
      image_path: result.poster_path,
      origin_country: nil,
      release_date: result.release_date,
      details: nil,
      in_libraries: (content && content.library_items) || []
    })
  end

  defp to_content_view(%TvSearchResult{} = result, content) do
    ContentView.new!(%{
      external_id_source: :tmdb,
      external_id: Integer.to_string(result.id),
      type: :tv_show,
      content: content,
      title: result.name,
      description: result.overview,
      image_path: result.poster_path,
      origin_country: nil,
      release_date: result.first_air_date,
      details: nil,
      in_libraries: (content && content.library_items) || []
    })
  end
end
