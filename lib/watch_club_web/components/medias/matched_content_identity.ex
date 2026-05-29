defmodule WatchClubWeb.Components.Medias.MatchedContentIdentity do
  @moduledoc """
  Single-line identity rendering of a matched piece of content
  (`Title · Sub` for episodes, `Title · Year` for movies/books with a release
  date, or just `Title` otherwise). Used for the Admin Media browser's
  mobile card view.
  """
  use WatchClubWeb, :component

  alias WatchClub.Contents.{Book, Movie, TvShowEpisode}

  attr :content, :any, required: true

  def matched_content_identity(%{content: %Movie{} = movie} = assigns) do
    render_identity(
      assigns,
      identity_text(movie.content.original_title, nil, year_of(movie.content))
    )
  end

  def matched_content_identity(%{content: %TvShowEpisode{} = episode} = assigns) do
    render_identity(
      assigns,
      identity_text(
        episode.tv_show.content.original_title,
        episode.formatted_episode_number,
        nil
      )
    )
  end

  def matched_content_identity(%{content: %Book{} = book} = assigns) do
    render_identity(assigns, identity_text(book.title, nil, year_of(book.content)))
  end

  defp render_identity(assigns, text) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <p class="truncate text-sm text-text-muted">{@text}</p>
    """
  end

  defp identity_text(title, sub, _year) when is_binary(sub), do: "#{title} · #{sub}"
  defp identity_text(title, _sub, year) when is_integer(year), do: "#{title} · #{year}"
  defp identity_text(title, _sub, _year), do: title

  defp year_of(%{release_date: %Date{year: year}}), do: year
  defp year_of(_), do: nil
end
