defmodule WatchClubWeb.Contents.TvShowDetailsPage.HeroPanel do
  @moduledoc """
  Hero panel for the TV Show detail page.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.ContentView
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse
  alias WatchClubWeb.Components.Contents.AddToLibraryButtonLive

  attr :tv_show, ContentView, required: true
  attr :current_user, User, required: true
  attr :available?, :boolean, required: true

  def hero_panel(assigns) do
    ~H"""
    <header class="relative flex justify-center py-cluster md:min-h-[32rem] md:py-section xl:min-h-[36rem] 2xl:col-span-2">
      <div class="relative z-1 grid content-start gap-cluster md:min-h-[28rem] xl:min-h-[32rem]">
        <p
          :if={@tv_show.details.tagline}
          class="justify-self-center text-center text-sm font-semibold tracking-[0.28em] text-accent uppercase"
        >
          {@tv_show.details.tagline}
        </p>

        <div class="grid content-start gap-cluster md:grid-cols-[11rem_minmax(0,1fr)] md:items-center xl:grid-cols-[15rem_minmax(0,1fr)]">
          <.tmdb_poster
            path={@tv_show.details.poster_path}
            size="w500"
            alt=""
            class="mx-auto w-44 rounded-card border border-border-subtle shadow-overlay md:mx-0 md:w-full"
          />

          <.stack space="group" class="self-center text-center md:text-left">
            <.stack space="related">
              <h1
                id="tv-show-details-title"
                class="text-4xl leading-none font-semibold tracking-tight text-text sm:text-5xl xl:text-6xl"
              >
                {@tv_show.title}
              </h1>

              <ul
                :if={metadata_items(@tv_show.details) != []}
                class="flex flex-wrap items-center justify-center gap-related text-text-muted md:justify-start"
              >
                <li
                  :for={{item, index} <- Enum.with_index(metadata_items(@tv_show.details))}
                  class="flex items-center gap-related"
                >
                  <span :if={index > 0} aria-hidden="true">•</span>
                  <span>{item}</span>
                </li>
              </ul>
            </.stack>

            <ul class="flex flex-wrap items-center justify-center gap-related text-text-muted md:justify-start">
              <li class="inline-flex items-center gap-tight">
                <Lucideicons.languages class="size-icon-sm text-accent" aria-hidden="true" />
                <span class="font-semibold text-text">
                  {original_language_label(@tv_show.details)}
                </span>
              </li>
              <li
                :if={primary_country(@tv_show.details)}
                class="inline-flex items-center gap-tight font-semibold text-text"
              >
                <span :if={primary_country(@tv_show.details).flag} aria-hidden="true">
                  {primary_country(@tv_show.details).flag}
                </span>
                {primary_country(@tv_show.details).name}
              </li>
            </ul>

            <p :if={show_original_title?(@tv_show, @tv_show.details)} class="text-center md:text-left">
              {dgettext("contents", "Original title")}:
              <span class="font-semibold text-text">{@tv_show.details.original_name}</span>
            </p>

            <ul
              :if={@tv_show.details.genres != []}
              class="flex flex-wrap items-center justify-center gap-related md:justify-start"
            >
              <li :for={genre <- @tv_show.details.genres}>
                <.badge variant="secondary">{genre.name}</.badge>
              </li>
            </ul>
          </.stack>
        </div>

        <.stack space="group" class="w-full items-center justify-self-center">
          <.availability_notice
            :if={!@available? && ContentView.in_clubs(@tv_show, @current_user) == []}
            tv_show={@tv_show}
          />
          <.hero_actions
            tv_show={@tv_show}
            current_user={@current_user}
            available?={@available?}
            trailer_url={trailer_url(@tv_show.details)}
          />
        </.stack>
      </div>
    </header>
    """
  end

  attr :tv_show, ContentView, required: true

  defp availability_notice(assigns) do
    ~H"""
    <div class="mx-auto max-w-readable rounded-card border border-accent-border bg-accent-bg p-group text-left text-sm leading-6 text-accent">
      <div class="flex gap-related">
        <Lucideicons.info class="mt-0.5 size-icon shrink-0 text-accent" />
        <p>
          {dgettext(
            "contents",
            "%{title} is not in your club libraries yet. Add it to a Library so every Member in that club can see it.",
            title: @tv_show.title
          )}
        </p>
      </div>
    </div>
    """
  end

  attr :tv_show, ContentView, required: true
  attr :current_user, User, required: true
  attr :available?, :boolean, required: true
  attr :trailer_url, :string, default: nil

  defp hero_actions(assigns) do
    ~H"""
    <.cluster class="w-full justify-center">
      <div :if={!@available?} class="w-full md:w-auto">
        <.live_component
          id="tv-show-details-add-to-library-button"
          module={AddToLibraryButtonLive}
          content={@tv_show}
          current_user={@current_user}
          on_content_updated={
            fn content_view ->
              send(self(), {:content_libraries_updated, content_view})
            end
          }
          class="w-full md:w-auto"
        />
      </div>
      <.button
        :if={@available?}
        id="tv-show-details-play-button"
        size="lg"
        variant="primary"
        emphasis
        class="w-full md:w-auto"
      >
        <:icon><Lucideicons.play /></:icon>
        {dgettext("contents", "Play")}
      </.button>
      <.button
        :if={@trailer_url}
        id="tv-show-details-watch-trailer-button"
        href={@trailer_url}
        target="_blank"
        size="lg"
        variant="secondary"
        class="w-full md:w-auto"
      >
        <:icon><Lucideicons.play_circle /></:icon>
        {dgettext("contents", "Watch Trailer")}
      </.button>
    </.cluster>
    """
  end

  defp metadata_items(%TvDetailsResponse{} = details) do
    [
      release_year(details.first_air_date),
      format_season_count(details.number_of_seasons || length(season_summaries(details))),
      translated_status(details.status)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp release_year(%Date{year: year}), do: Integer.to_string(year)
  defp release_year(_), do: nil

  defp format_season_count(nil), do: nil
  defp format_season_count(0), do: nil

  defp format_season_count(count) do
    dngettext("contents", "%{count} season", "%{count} seasons", count, count: count)
  end

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

  defp primary_country(%TvDetailsResponse{} = details) do
    country = List.first(details.production_countries)
    code = (country && country.iso_3166_1) || List.first(details.origin_country)
    name = (country && country.name) || code

    if name do
      %{name: name, flag: WatchClub.Languages.to_flag(code)}
    end
  end

  defp original_language_label(%TvDetailsResponse{} = details) do
    details.spoken_languages
    |> Enum.find(&(&1.iso_639_1 == details.original_language))
    |> case do
      %{english_name: english_name} when english_name not in [nil, ""] -> english_name
      %{name: name} when name not in [nil, ""] -> name
      _ -> String.upcase(details.original_language || "")
    end
  end

  defp show_original_title?(%ContentView{title: title}, %TvDetailsResponse{
         original_name: original_name
       }) do
    original_name not in [nil, ""] and original_name != title
  end

  defp trailer_url(%TvDetailsResponse{} = details) do
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
