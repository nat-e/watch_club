defmodule WatchClub.History.MarkWatchedReproTest do
  use WatchClub.DataCase

  require Ash.Query

  alias WatchClub.Contents
  alias WatchClub.Contents.{Content, Movie}
  alias WatchClub.History

  test "marking a partially-watched movie as watched marks it completed" do
    user = generate(user())

    content =
      Ash.Seed.seed!(Content, %{
        type: :movie,
        external_id_source: :tmdb,
        external_id: "movie-repro-1",
        original_title: "Repro Movie",
        original_language: "en",
        origin_country: "US"
      })

    movie = Ash.Seed.seed!(Movie, %{id: content.id})
    identity = Contents.ContentIdentity.from_content(content)

    # Watch 28% of the movie
    History.record_movie_progress!(
      %{movie_id: movie.id, position_seconds: 1724.9, duration_seconds: 6204.1},
      actor: user
    )

    # Mark as watched
    History.mark_content_watched!(identity, actor: user)

    progress =
      History.WatchProgress
      |> Ash.Query.filter(movie_id == ^movie.id and user_id == ^user.id)
      |> Ash.read_one!(actor: user, load: [:completed, :percent_watched])

    assert progress.completed
    assert progress.percent_watched == 100.0
  end
end
