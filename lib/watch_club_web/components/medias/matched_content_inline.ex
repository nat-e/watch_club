defmodule WatchClubWeb.Components.Medias.MatchedContentInline do
  @moduledoc """
  Compact inline rendering of a matched piece of content — title text with an
  optional secondary badge (e.g. `S01E02`). Used for the Admin Media browser's
  table-row title cell.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.UI.Badge

  alias WatchClub.Contents.{Book, Movie, TvShowEpisode}

  attr :content, :any, required: true

  def matched_content_inline(%{content: %Movie{} = movie} = assigns) do
    render_inline(assigns, movie.content.original_title, nil)
  end

  def matched_content_inline(%{content: %TvShowEpisode{} = episode} = assigns) do
    render_inline(
      assigns,
      episode.tv_show.content.original_title,
      episode.formatted_episode_number
    )
  end

  def matched_content_inline(%{content: %Book{} = book} = assigns) do
    render_inline(assigns, book.title, nil)
  end

  defp render_inline(assigns, title, sub) do
    tooltip = if is_binary(sub), do: "#{title} · #{sub}", else: title

    assigns =
      assigns
      |> assign(:title, title)
      |> assign(:sub, sub)
      |> assign(:tooltip, tooltip)

    ~H"""
    <div class="flex items-center gap-tight min-w-0" title={@tooltip}>
      <span class="truncate text-sm text-text-muted">{@title}</span>
      <.badge :if={@sub} variant="secondary" size="sm" class="shrink-0">{@sub}</.badge>
    </div>
    """
  end
end
