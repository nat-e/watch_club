defmodule WatchClub.Contents.Calculations.ActorNextMediasToPlay do
  use Ash.Resource.Calculation

  alias WatchClub.Contents.{Book, Movie, SportsEvent, TvShow}

  @impl true
  def load(_, _, _) do
    [
      implementation: %{
        load: [
          book: [:audiobooks, :ebooks],
          movie: [:actor_video_to_play],
          sports_event: [:actor_video_to_play],
          tv_show: [actor_next_episode: [:actor_video_to_play]]
        ]
      }
    ]
  end

  # This ensures that all attributes are selected by default
  # on the related loads we depend on.
  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(records, _, _) do
    Enum.map(records, fn record ->
      case record.implementation do
        %Book{} = book ->
          book.audiobooks ++ book.ebooks

        %Movie{} = movie ->
          List.wrap(movie.actor_video_to_play)

        %SportsEvent{} = event ->
          List.wrap(event.actor_video_to_play)

        %TvShow{} = tv_show ->
          episode = tv_show.actor_next_episode
          List.wrap(episode && episode.actor_video_to_play)
      end
    end)
  end
end
