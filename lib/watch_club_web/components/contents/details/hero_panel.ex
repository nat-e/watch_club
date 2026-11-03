defmodule WatchClubWeb.Components.Contents.Details.HeroPanel do
  @moduledoc """
  Hero panel shared by the Movie and TV Show detail pages.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.ContentIdentity
  alias WatchClub.Integrations.Tmdb.{MovieDetailsResponse, TvDetailsResponse}

  alias WatchClubWeb.Components.Contents.{
    ContentWatchProgressBadge,
    PlayOrRequestButtonLive
  }

  alias WatchClubWeb.Helpers.Time

  attr :content_identity, ContentIdentity, required: true

  attr :content, :any,
    required: true,
    doc: "An instance of MovieDetailsResponse or TvDetailsResponse"

  attr :current_user, User, required: true

  def hero_panel(assigns) do
    ~H"""
    <header class="relative flex justify-center py-cluster @xl:py-section">
      <div class="relative flex flex-col gap-cluster">
        <p
          :if={@content.tagline}
          class="text-center text-sm font-semibold tracking-wider text-accent uppercase"
        >
          {@content.tagline}
        </p>

        <div class="flex flex-col gap-cluster @xl:flex-row @xl:items-center">
          <.tmdb_poster
            path={@content.poster_path}
            size="w500"
            alt=""
            class="mx-auto w-44 shrink-0 border border-border-subtle shadow-overlay @xl:mx-0 @5xl:w-60"
          />

          <div class="flex flex-col items-center gap-group text-center @xl:flex-1 @xl:items-start @xl:text-left">
            <div class="flex flex-col items-center gap-related @xl:items-start">
              <.live_component
                id={ContentWatchProgressBadge.dom_id(@content_identity)}
                module={ContentWatchProgressBadge}
                content_identity={@content_identity}
                current_user={@current_user}
              />
              <h1
                id="content-details-title"
                data-page-title
                class="text-4xl leading-none font-semibold tracking-tight text-text"
              >
                {title(@content)}
              </h1>
              <ul
                :if={metadata_items(@content) != []}
                class="flex flex-wrap items-center gap-related text-text-muted"
              >
                <li
                  :for={{item, index} <- Enum.with_index(metadata_items(@content))}
                  class="flex items-center gap-related"
                >
                  <span :if={index > 0} aria-hidden="true">•</span>
                  <span>{item}</span>
                </li>
              </ul>
            </div>

            <ul class="flex flex-wrap items-center gap-related text-text-muted">
              <li class="inline-flex items-center gap-tight">
                <Lucideicons.languages class="size-icon-sm text-accent" aria-hidden="true" />
                <span class="font-semibold text-text">
                  {original_language_label(@content)}
                </span>
              </li>
              <li
                :if={primary_country(@content)}
                class="inline-flex items-center gap-tight font-semibold text-text"
              >
                <span aria-hidden="true">
                  {primary_country(@content).flag}
                </span>
                {primary_country(@content).name}
              </li>
            </ul>

            <p :if={show_original_title?(@content)}>
              {dgettext("contents", "Original title")}:
              <span class="font-semibold text-text">{original_title(@content)}</span>
            </p>

            <ul :if={@content.genres != []} class="flex flex-wrap items-center gap-related">
              <li :for={genre <- @content.genres}>
                <.badge variant="secondary">{genre.name}</.badge>
              </li>
            </ul>
          </div>
        </div>

        <.hero_actions
          content_identity={@content_identity}
          content={@content}
          current_user={@current_user}
        />
      </div>
    </header>
    """
  end

  attr :content_identity, ContentIdentity, required: true

  attr :content, :any,
    required: true,
    doc: "An instance of MovieDetailsResponse or TvDetailsResponse"

  attr :current_user, User, required: true

  defp hero_actions(assigns) do
    assigns = assigns |> assign(trailer_url: trailer_url(assigns.content))

    ~H"""
    <.cluster class="w-full justify-center">
      <.live_component
        id={PlayOrRequestButtonLive.dom_id(@content_identity)}
        module={PlayOrRequestButtonLive}
        content_identity={@content_identity}
        current_user={@current_user}
        size="lg"
        class="w-full @xl:w-auto"
      />
      <.button
        id="details-add-to-list-button"
        phx-click="open_add_to_list_modal"
        size="lg"
        variant="secondary"
        class="w-full @xl:w-auto"
      >
        <:icon><Lucideicons.list_plus /></:icon>
        {dgettext("contents", "Add to List")}
      </.button>
      <.button
        :if={@trailer_url}
        id="details-watch-trailer-button"
        href={@trailer_url}
        target="_blank"
        size="lg"
        variant="secondary"
        class="w-full @xl:w-auto"
      >
        <:icon><Lucideicons.play_circle /></:icon>
        {dgettext("contents", "Watch Trailer")}
      </.button>
    </.cluster>
    """
  end

  defp title(%MovieDetailsResponse{} = details), do: details.title
  defp title(%TvDetailsResponse{} = details), do: details.name

  defp metadata_items(%MovieDetailsResponse{} = details) do
    [
      Time.maybe_year(details.release_date),
      format_runtime(details.runtime),
      translated_status(details.status)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp metadata_items(%TvDetailsResponse{} = details) do
    [
      Time.maybe_year(details.first_air_date),
      format_season_count(details.number_of_seasons || length(season_summaries(details))),
      translated_status(details.status)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp format_runtime(nil), do: nil

  defp format_runtime(minutes) when is_integer(minutes) and minutes < 60 do
    dngettext("contents", "%{count} minute", "%{count} minutes", minutes)
  end

  defp format_runtime(minutes) when is_integer(minutes) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)

    if remaining_minutes == 0 do
      dgettext("contents", "%{hours}h", hours: hours)
    else
      dgettext("contents", "%{hours}h %{minutes}m", hours: hours, minutes: remaining_minutes)
    end
  end

  defp format_season_count(0), do: nil

  defp format_season_count(count) do
    dngettext("contents", "%{count} season", "%{count} seasons", count, count: count)
  end

  defp translated_status("Released"), do: dgettext("contents", "Released")
  defp translated_status("Ended"), do: dgettext("contents", "Ended")
  defp translated_status("Returning Series"), do: dgettext("contents", "Returning Series")
  defp translated_status("Canceled"), do: dgettext("contents", "Canceled")
  defp translated_status(nil), do: nil
  defp translated_status(status), do: status

  defp season_summaries(%TvDetailsResponse{} = details) do
    details.seasons
    |> Enum.filter(&(&1.season_number >= 1 and &1.episode_count > 0))
    |> Enum.sort_by(& &1.season_number)
  end

  defp primary_country(details) do
    country = List.first(details.production_countries)
    code = (country && country.iso_3166_1) || List.first(details.origin_country)
    name = (country && country.name) || code

    if name do
      %{name: name, flag: WatchClub.Languages.country_flag(code)}
    end
  end

  defp original_language_label(details) do
    details.spoken_languages
    |> Enum.find(&(&1.iso_639_1 == details.original_language))
    |> case do
      %{english_name: english_name} when english_name not in [nil, ""] -> english_name
      %{name: name} when name not in [nil, ""] -> name
      _ -> String.upcase(details.original_language || "")
    end
  end

  defp original_title(%MovieDetailsResponse{original_title: original_title}), do: original_title
  defp original_title(%TvDetailsResponse{original_name: original_name}), do: original_name

  defp show_original_title?(content) do
    original = original_title(content)
    original not in [nil, ""] and original != title(content)
  end

  defp trailer_url(details) do
    videos = (details.videos && details.videos.results) || []

    videos
    |> best_trailer()
    |> case do
      %{site: "YouTube", key: key} when key not in [nil, ""] ->
        "https://www.youtube.com/watch?v=#{key}"

      _ ->
        nil
    end
  end

  defp best_trailer(videos) do
    Enum.find(videos, &(&1.site == "YouTube" and &1.type == "Trailer" and &1.official)) ||
      Enum.find(videos, &(&1.site == "YouTube" and &1.type == "Trailer")) ||
      Enum.find(videos, &(&1.site == "YouTube" and &1.type == "Teaser"))
  end
end
