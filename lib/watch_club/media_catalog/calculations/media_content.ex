defmodule WatchClub.MediaCatalog.Calculations.MediaContent do
  @moduledoc """
  Resolves the `Content` a Media represents, regardless of its media type. A
  video resolves through its `Movie` or `TvShowEpisode`; an ebook or audiobook
  through its `Book`. Returns `nil` only for a Media with no attached content.
  """

  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [
      video: [movie: :content, tv_show_episode: [tv_show: :content]],
      ebook: [book: :content],
      audiobook: [book: :content]
    ]
  end

  # Select all attributes on the related Content we return, not just the keys.
  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(media, _opts, _context) do
    Enum.map(media, fn media ->
      cond do
        media.video && media.video.movie ->
          media.video.movie.content

        media.video && media.video.tv_show_episode ->
          media.video.tv_show_episode.tv_show.content

        media.ebook ->
          media.ebook.book.content

        media.audiobook ->
          media.audiobook.book.content

        true ->
          nil
      end
    end)
  end
end
