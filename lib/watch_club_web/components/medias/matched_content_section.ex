defmodule WatchClubWeb.Components.Medias.MatchedContentSection do
  @moduledoc """
  Renders a poster + title + metadata block for a matched piece of content.

  Accepts a polymorphic `:content` argument — currently a `Movie`,
  `TvShowEpisode`, or `Book`. Each clause reads its own fields and feeds a
  shared layout; callers do no drilling.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.UI.Badge
  import WatchClubWeb.Components.UI.Layout
  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.{Book, Movie, TvShowEpisode}

  alias WatchClubWeb.Helpers.Time

  attr :content, :any, required: true

  def matched_content_section(%{content: %Movie{} = movie} = assigns) do
    render_section(
      assigns,
      poster_path: movie.best_localization && movie.best_localization.poster_path,
      title: movie.content.original_title,
      meta: meta_items(movie.content),
      sub_badge: nil
    )
  end

  def matched_content_section(%{content: %TvShowEpisode{} = episode} = assigns) do
    show = episode.tv_show

    render_section(
      assigns,
      poster_path: show.best_localization && show.best_localization.poster_path,
      title: show.content.original_title,
      meta: meta_items(show.content),
      sub_badge: episode.formatted_episode_number
    )
  end

  def matched_content_section(%{content: %Book{} = book} = assigns) do
    render_section(
      assigns,
      poster_path: nil,
      title: book.title,
      meta: meta_items(book.content),
      sub_badge: nil
    )
  end

  defp render_section(assigns, fields) do
    assigns =
      assigns
      |> assign(:poster_path, fields[:poster_path])
      |> assign(:title, fields[:title])
      |> assign(:meta, fields[:meta])
      |> assign(:sub_badge, fields[:sub_badge])

    ~H"""
    <div class="flex items-start gap-cluster">
      <.tmdb_poster
        path={@poster_path}
        size="w185"
        alt={@title}
        class="w-24 shrink-0 border border-border-subtle"
      />

      <.stack space="related" class="min-w-0 flex-1 self-center">
        <h2 class="text-xl font-heading font-semibold leading-tight tracking-tight text-text">
          {@title}
        </h2>

        <ul
          :if={@meta != []}
          class="flex flex-wrap items-center gap-related text-base text-text-muted"
        >
          <li
            :for={{item, index} <- Enum.with_index(@meta)}
            class="flex items-center gap-related"
          >
            <span :if={index > 0} aria-hidden="true">·</span>
            <span>{item}</span>
          </li>
        </ul>

        <div :if={@sub_badge}>
          <.badge variant="secondary">{@sub_badge}</.badge>
        </div>
      </.stack>
    </div>
    """
  end

  defp meta_items(content) do
    [Time.maybe_year(content.release_date), language(content), country(content)]
    |> Enum.reject(&is_nil/1)
  end

  defp language(%{original_language: lang}) when is_binary(lang) and lang != "",
    do: String.upcase(lang)

  defp language(_), do: nil

  defp country(%{origin_country: code}) when is_binary(code) and code != "",
    do: "#{WatchClub.Languages.country_flag(code)} #{code}"

  defp country(_), do: nil
end
