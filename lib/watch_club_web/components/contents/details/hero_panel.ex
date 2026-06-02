defmodule WatchClubWeb.Components.Contents.Details.HeroPanel do
  @moduledoc """
  Hero panel shared by the Movie and TV Show detail pages.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.ContentView
  alias WatchClub.Integrations.Tmdb.{MovieDetailsResponse, TvDetailsResponse}
  alias WatchClubWeb.Components.Contents.{AddToLibraryButtonLive, PlayOrRequestButtonLive}

  attr :content, ContentView, required: true
  attr :current_user, User, required: true

  def hero_panel(assigns) do
    ~H"""
    <header class="relative flex justify-center py-cluster md:min-h-[32rem] md:py-section xl:min-h-[36rem] 2xl:col-span-2">
      <div class="relative z-1 grid content-start gap-cluster md:min-h-[28rem] xl:min-h-[32rem]">
        <p
          :if={@content.details.tagline}
          class="justify-self-center text-center text-sm font-semibold tracking-[0.28em] text-accent uppercase"
        >
          {@content.details.tagline}
        </p>

        <div class="grid content-start gap-cluster md:grid-cols-[11rem_minmax(0,1fr)] md:items-center xl:grid-cols-[15rem_minmax(0,1fr)]">
          <.tmdb_poster
            path={@content.details.poster_path}
            size="w500"
            alt=""
            class="mx-auto w-44 rounded-card border border-border-subtle shadow-overlay md:mx-0 md:w-full"
          />

          <.stack space="group" class="self-center text-center md:text-left">
            <.stack space="related">
              <h1
                id="content-details-title"
                class="text-4xl leading-none font-semibold tracking-tight text-text sm:text-5xl xl:text-6xl"
              >
                {@content.title}
              </h1>

              <ul
                :if={metadata_items(@content.details) != []}
                class="flex flex-wrap items-center justify-center gap-related text-text-muted md:justify-start"
              >
                <li
                  :for={{item, index} <- Enum.with_index(metadata_items(@content.details))}
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
                  {original_language_label(@content.details)}
                </span>
              </li>
              <li
                :if={primary_country(@content.details)}
                class="inline-flex items-center gap-tight font-semibold text-text"
              >
                <span :if={primary_country(@content.details).flag} aria-hidden="true">
                  {primary_country(@content.details).flag}
                </span>
                {primary_country(@content.details).name}
              </li>
            </ul>

            <p :if={show_original_title?(@content)} class="text-center md:text-left">
              {dgettext("contents", "Original title")}:
              <span class="font-semibold text-text">{original_title(@content.details)}</span>
            </p>

            <ul
              :if={@content.details.genres != []}
              class="flex flex-wrap items-center justify-center gap-related md:justify-start"
            >
              <li :for={genre <- @content.details.genres}>
                <.badge variant="secondary">{genre.name}</.badge>
              </li>
            </ul>
          </.stack>
        </div>

        <.stack space="group" class="w-full items-center justify-self-center">
          <%!-- <.availability_notice
            :if={!@available? && ContentView.in_clubs(@content, @current_user) == []}
            content={@content}
          /> --%>
          <.hero_actions content={@content} current_user={@current_user} />
        </.stack>
      </div>
    </header>
    """
  end

  # attr :content, ContentView, required: true
  #
  # defp availability_notice(assigns) do
  #   ~H"""
  #   <div class="mx-auto max-w-readable rounded-card border border-accent-border bg-accent-bg p-group text-left text-sm leading-6 text-accent">
  #     <div class="flex gap-related">
  #       <Lucideicons.info class="mt-0.5 size-icon shrink-0 text-accent" />
  #       <p>
  #         {dgettext(
  #           "contents",
  #           "%{title} is not in your club libraries yet. Add it to a Library so every Member in that club can see it.",
  #           title: @content.title
  #         )}
  #       </p>
  #     </div>
  #   </div>
  #   """
  # end

  attr :content, ContentView, required: true
  attr :current_user, User, required: true

  defp hero_actions(assigns) do
    assigns = assign(assigns, :trailer_url, trailer_url(assigns.content.details))

    ~H"""
    <.cluster class="w-full justify-center">
      <.live_component
        id="details-play-or-request-button"
        module={PlayOrRequestButtonLive}
        content={@content}
        current_user={@current_user}
        class="w-full md:w-auto"
      />
      <.live_component
        id="details-add-to-library-button"
        module={AddToLibraryButtonLive}
        content={@content}
        current_user={@current_user}
        on_content_updated={
          fn content_view ->
            send(self(), {:content_libraries_updated, content_view})
          end
        }
        class="w-full md:w-auto"
      />
      <.button
        :if={@trailer_url}
        id="details-watch-trailer-button"
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

  defp metadata_items(%MovieDetailsResponse{} = details) do
    [
      release_year(details.release_date),
      format_runtime(details.runtime),
      translated_status(details.status)
    ]
    |> Enum.reject(&is_nil/1)
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

  defp format_season_count(nil), do: nil
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
      %{name: name, flag: WatchClub.Languages.to_flag(code)}
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

  defp show_original_title?(%ContentView{title: title} = content) do
    original = original_title(content.details)
    original not in [nil, ""] and original != title
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
