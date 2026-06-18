defmodule WatchClub.Contents.Calculations.ActorNextMediasToPlay do
  use Ash.Resource.Calculation

  @impl true
  def load(_, _, _) do
    [book: [:audiobooks, :ebooks], movie: [:videos], tv_show: [actor_next_episode: [:videos]]]
  end

  # This ensures that all attributes are selected by default
  # on the related loads we depend on.
  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(records, _, _) do
    Enum.map(records, fn record ->
      cond do
        record.book ->
          record.book.audiobooks ++ record.book.ebooks

        record.movie ->
          record.movie.videos

        record.tv_show ->
          record.tv_show.actor_next_episode.videos
      end
    end)
  end
end
