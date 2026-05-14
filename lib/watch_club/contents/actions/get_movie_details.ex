defmodule WatchClub.Contents.Actions.GetMovieDetails do
  use Ash.Resource.Actions.Implementation

  require Ash.Query
  alias WatchClub.Contents.{Content, ContentView}
  alias WatchClub.Integrations.Tmdb

  @impl true
  def run(
        %Ash.ActionInput{arguments: %{tmdb_id: tmdb_id}},
        _opts,
        %Ash.Resource.Actions.Implementation.Context{actor: actor}
      ) do
    actor_locale = actor.settings.locale
    details_task = Task.async(fn -> Tmdb.get_movie_details(tmdb_id, locale: actor_locale) end)
    content_task = Task.async(fn -> get_content(tmdb_id, actor) end)

    with {:ok, details} <- Task.await(details_task),
         {:ok, content} <- Task.await(content_task) do
      {:ok, to_content_view(details, content)}
    end
  end

  defp get_content(tmdb_id, user) do
    Content
    |> Ash.Query.filter(external_id_source == :tmdb and external_id == ^tmdb_id)
    |> Ash.read_first(action: :for_view, actor: user)
  end

  defp to_content_view(%Tmdb.MovieDetailsResponse{} = details, content) do
    ContentView.new!(%{
      external_id_source: :tmdb,
      external_id: Integer.to_string(details.id),
      type: :movie,
      content: content,
      title: details.title,
      description: details.overview,
      image_path: details.poster_path,
      origin_country: List.first(details.origin_country),
      release_date: details.release_date,
      details: details,
      in_libraries: (content && content.library_items) || []
    })
  end
end
