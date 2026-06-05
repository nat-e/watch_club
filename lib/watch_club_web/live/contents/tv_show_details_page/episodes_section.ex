defmodule WatchClubWeb.Contents.TvShowDetailsPage.EpisodesSection do
  @moduledoc """
  Episodes section for the TV Show detail page.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Accounts.{User, UserLocale}
  alias WatchClub.Contents.{ContentView, TvShowEpisode}
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse.SeasonDetails

  alias WatchClubWeb.Components.Contents.EpisodeWatchProgressBadge

  attr :content, ContentView, required: true
  attr :details, TvDetailsResponse, required: true
  attr :selected_season, :integer, required: true
  attr :season_metadata_by_number, :map, required: true
  attr :current_user, User, required: true

  def episodes_section(assigns) do
    ~H"""
    <.card padding="none" class="overflow-hidden">
      <div class="p-cluster">
        <div class="flex items-center gap-related">
          <span class="inline-flex size-control-md items-center justify-center text-accent">
            <Lucideicons.list_video class="size-icon" />
          </span>
          <h2 class="text-xl font-semibold tracking-tight text-text">
            {dgettext("contents", "Episodes")}
          </h2>
        </div>
      </div>

      <div class="grid border-t border-border-subtle lg:grid-cols-[8rem_minmax(0,1fr)]">
        <div class="border-b border-border-subtle bg-surface-inset p-tight lg:border-r lg:border-b-0">
          <.season_selector seasons={season_summaries(@details)} selected_season={@selected_season} />
        </div>
        <.season_panel
          content={@content}
          current_user={@current_user}
          selected_season_summary={
            selected_season_summary(season_summaries(@details), @selected_season)
          }
          season_metadata={
            Map.fetch!(
              @season_metadata_by_number,
              selected_season_summary(season_summaries(@details), @selected_season).season_number
            )
          }
          class="p-group"
        />
      </div>
    </.card>
    """
  end

  attr :seasons, :list, required: true
  attr :selected_season, :integer, required: true

  defp season_selector(assigns) do
    ~H"""
    <div
      role="tablist"
      aria-label={dgettext("contents", "Seasons")}
      class="flex gap-tight overflow-x-auto lg:grid lg:gap-tight"
    >
      <.season_tab_button
        :for={season <- @seasons}
        season={season}
        selected?={season.season_number == @selected_season}
      />
    </div>
    """
  end

  attr :season, :map, required: true
  attr :selected?, :boolean, required: true

  defp season_tab_button(assigns) do
    ~H"""
    <button
      id={"tv-show-season-tab-#{@season.season_number}"}
      type="button"
      role="tab"
      aria-selected={@selected?}
      aria-controls="tv-show-season-panel"
      phx-click="select_season"
      phx-value-season={@season.season_number}
      class={[
        "min-h-touch-target shrink-0 rounded-control px-related py-related text-left transition-colors focus-visible:ring-2 focus-visible:ring-focus-ring focus-visible:outline-none lg:w-full",
        @selected? && "border border-border bg-surface-selected text-text shadow-card",
        !@selected? &&
          "border border-transparent text-text-muted hover:bg-surface-hover hover:text-text"
      ]}
    >
      <span class="block text-sm font-semibold">
        {dgettext("contents", "Season %{number}", number: @season.season_number)}
      </span>
      <span :if={year(@season.air_date)} class="text-xs">{year(@season.air_date)}</span>
    </button>
    """
  end

  attr :content, ContentView, required: true
  attr :selected_season_summary, :map, required: true
  attr :season_metadata, :map, required: true
  attr :current_user, User, required: true
  attr :class, :any, default: nil

  defp season_panel(%{season_metadata: %{status: :loaded}} = assigns) do
    ~H"""
    <div
      id="tv-show-season-panel"
      role="tabpanel"
      aria-labelledby={"tv-show-season-tab-#{@season_metadata.details.season_number}"}
      class={["grid gap-cluster", @class]}
    >
      <section class="grid gap-group md:grid-cols-[8rem_minmax(0,1fr)] md:items-center">
        <.tmdb_poster
          path={@season_metadata.details.poster_path}
          size="w342"
          alt=""
          class="w-32 rounded-control border border-border-subtle bg-surface-raised md:w-full"
        />

        <div class="grid gap-related">
          <div class="flex flex-wrap items-center gap-related">
            <h3 class="text-2xl font-semibold tracking-tight text-text">
              {dgettext("contents", "Season %{number}",
                number: @season_metadata.details.season_number
              )}
            </h3>
            <span :if={year(@season_metadata.details.air_date)} class="text-sm text-text-muted">
              {year(@season_metadata.details.air_date)}
            </span>
          </div>
          <p
            :if={@season_metadata.details.overview}
            class="line-clamp-3 text-sm leading-6 text-text-muted"
          >
            {@season_metadata.details.overview}
          </p>
          <ul
            :if={@season_metadata.details.vote_average}
            class="flex flex-wrap items-center gap-related text-sm text-text-muted"
          >
            <li class="inline-flex items-center gap-tight">
              <Lucideicons.star class="size-icon-sm text-success" />
              {format_score(@season_metadata.details.vote_average)}
            </li>
          </ul>
        </div>
      </section>

      <div class="grid gap-related">
        <.episode_row
          :for={episode_details <- @season_metadata.details.episodes}
          episode={
            ContentView.episode(
              @content,
              episode_details.season_number,
              episode_details.episode_number
            )
          }
          content={@content}
          episode_details={episode_details}
          current_user={@current_user}
        />
      </div>
    </div>
    """
  end

  defp season_panel(%{season_metadata: %{status: :failed}} = assigns) do
    ~H"""
    <div
      id="tv-show-season-panel"
      role="tabpanel"
      aria-labelledby={"tv-show-season-tab-#{@selected_season_summary.season_number}"}
      class={["grid gap-cluster", @class]}
    >
      <.empty border={false} class="min-h-[24rem] rounded-control bg-surface-inset">
        <:icon><Lucideicons.cloud_off /></:icon>
        <:title>{dgettext("contents", "Error loading season")}</:title>
        <:description>
          {dgettext("contents", "We couldn't load the season. Please try again")}
        </:description>
        <.button
          id={"tv-show-season-retry-button-#{@selected_season_summary.season_number}"}
          phx-click="retry_season_metadata"
          phx-value-season={@selected_season_summary.season_number}
          variant="secondary"
          size="sm"
        >
          <:icon><Lucideicons.refresh_ccw /></:icon>
          {dgettext("contents", "Try again")}
        </.button>
      </.empty>
    </div>
    """
  end

  defp season_panel(assigns) do
    ~H"""
    <div
      id="tv-show-season-panel"
      role="tabpanel"
      aria-labelledby={"tv-show-season-tab-#{@selected_season_summary.season_number}"}
      aria-busy="true"
      class={["grid gap-cluster", @class]}
    >
      <span class="sr-only">{dgettext("contents", "Loading season episodes")}</span>
      <section class="grid gap-group md:grid-cols-[8rem_minmax(0,1fr)] md:items-center">
        <div class="aspect-2/3 w-32 animate-pulse rounded-control border border-border-subtle bg-surface-raised md:w-full">
        </div>
        <div class="grid gap-related">
          <div class="h-8 w-48 animate-pulse rounded-full bg-surface-raised"></div>
          <div class="grid gap-tight">
            <div class="h-4 w-full max-w-readable animate-pulse rounded-full bg-surface-raised"></div>
            <div class="h-4 w-4/5 max-w-readable animate-pulse rounded-full bg-surface-raised"></div>
          </div>
        </div>
      </section>

      <div class="grid gap-related">
        <div
          :for={_index <- episode_skeleton_indexes(@selected_season_summary.episode_count)}
          class="grid gap-group rounded-control border border-border bg-surface p-related shadow-card md:grid-cols-[13rem_minmax(0,1fr)]"
        >
          <div class="aspect-video animate-pulse rounded-control border border-border-subtle bg-surface-raised">
          </div>
          <div class="grid content-start gap-related">
            <div class="h-5 w-3/5 animate-pulse rounded-full bg-surface-raised"></div>
            <div class="h-4 w-full animate-pulse rounded-full bg-surface-raised"></div>
            <div class="h-4 w-4/5 animate-pulse rounded-full bg-surface-raised"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :content, ContentView, required: true
  attr :episode_details, SeasonDetails.Episode, required: true
  attr :current_user, User, required: true
  attr :episode, TvShowEpisode

  defp episode_row(assigns) do
    ~H"""
    <article class="grid gap-group rounded-control border border-border bg-surface p-related shadow-card md:grid-cols-[13rem_minmax(0,1fr)]">
      <.tmdb_still
        size="w300"
        path={@episode_details.still_path}
        class="rounded-control"
      >
        <.link
          :if={@episode && @episode.playable?}
          id={"#{@episode_details.id}-episode-play"}
          href={episode_play_link(@episode)}
          aria-label="Play"
          class="absolute inset-0 flex items-center justify-center"
        >
          <span class="flex size-12 items-center justify-center rounded-full bg-primary text-on-primary shadow-overlay">
            <Lucideicons.play class="size-icon" />
          </span>
        </.link>
      </.tmdb_still>

      <div class="grid min-w-0 content-start gap-related">
        <div class="flex flex-wrap items-start justify-between gap-related">
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-related">
              <.badge variant="muted" size="sm">
                S{pad(@episode_details.season_number)}E{pad(@episode_details.episode_number)}
              </.badge>
              <h4 class="text-lg leading-tight font-semibold text-text">{@episode_details.name}</h4>
            </div>
          </div>

          <.live_component
            id={"episode-progress-badge-#{@episode_details.id}"}
            module={EpisodeWatchProgressBadge}
            content={@content}
            season_number={@episode_details.season_number}
            episode_number={@episode_details.episode_number}
            current_user={@current_user}
          />
        </div>

        <p :if={@episode_details.overview} class="text-sm leading-6 text-text-muted">
          {@episode_details.overview}
        </p>

        <ul class="flex flex-wrap items-center gap-related text-sm text-text-subtle">
          <li
            :if={format_date(@episode_details.air_date, @current_user.settings.locale)}
            class="inline-flex items-center gap-tight"
          >
            <Lucideicons.calendar_days class="size-icon-sm" />
            {format_date(@episode_details.air_date, @current_user.settings.locale)}
          </li>
          <li
            :if={format_runtime(@episode_details.runtime)}
            class="inline-flex items-center gap-tight"
          >
            <Lucideicons.clock class="size-icon-sm" />
            {format_runtime(@episode_details.runtime)}
          </li>
        </ul>
      </div>
    </article>
    """
  end

  defp episode_play_link(%TvShowEpisode{} = episode),
    do: ~p"/play/#{List.first(episode.videos).id}"

  defp season_summaries(%TvDetailsResponse{} = details) do
    details.seasons
    |> Enum.filter(&(&1.season_number >= 1 and &1.episode_count > 0))
    |> Enum.sort_by(& &1.season_number)
  end

  defp selected_season_summary(season_summaries, selected_season) do
    Enum.find(season_summaries, &(&1.season_number == selected_season)) ||
      List.first(season_summaries)
  end

  defp episode_skeleton_indexes(count) when is_integer(count) and count > 0, do: 1..count
  defp episode_skeleton_indexes(_), do: []

  defp year(%Date{year: year}), do: Integer.to_string(year)
  defp year(_), do: nil

  defp format_date(nil, _locale), do: nil

  defp format_date(%Date{} = date, locale) do
    WatchClub.Cldr.Date.to_string!(date,
      format: :medium,
      locale: UserLocale.to_cldr_locale_name(locale)
    )
  end

  defp format_runtime(nil), do: nil

  defp format_runtime(minutes) when is_integer(minutes) do
    dngettext("contents", "%{count} minute", "%{count} minutes", minutes)
  end

  defp format_score(score) when is_number(score) do
    score
    |> Kernel.*(1.0)
    |> :erlang.float_to_binary(decimals: 1)
  end

  defp format_score(_), do: nil

  defp pad(number), do: number |> Integer.to_string() |> String.pad_leading(2, "0")
end
