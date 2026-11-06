defmodule WatchClubWeb.Helpers.ContentDetails do
  @moduledoc """
  What pages show of a Content's details from TMDB, a `MovieDetailsResponse` or a
  `TvDetailsResponse`: its name, release date, length and seasons.
  """
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Integrations.Tmdb.{MovieDetailsResponse, TvDetailsResponse}
  alias WatchClubWeb.Helpers.Time

  def title(%MovieDetailsResponse{title: title}), do: title
  def title(%TvDetailsResponse{name: name}), do: name

  def release_date(%MovieDetailsResponse{release_date: date}), do: date
  def release_date(%TvDetailsResponse{first_air_date: date}), do: date

  @doc """
  A Movie's runtime, like "2 hr 9 min", or a TV Show's number of seasons. Nil when unknown.
  """
  def length_label(%MovieDetailsResponse{runtime: minutes}, locale),
    do: Time.minutes(minutes, locale)

  def length_label(%TvDetailsResponse{} = details, _locale) do
    case length(season_numbers(details)) do
      0 -> nil
      count -> dngettext("contents", "%{count} season", "%{count} seasons", count)
    end
  end

  @doc """
  The seasons of a TV Show with episodes, without its specials.
  """
  def season_numbers(%TvDetailsResponse{} = details) do
    for season <- details.seasons,
        season.season_number >= 1 and season.episode_count > 0,
        do: season.season_number
  end
end
