defmodule WatchClubWeb.Contents.TvShowDetailsPage.EpisodesSection do
  @moduledoc """
  Episodes section for the TV Show detail page.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Integrations.Tmdb.TvDetailsResponse
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse.SeasonDetails

  alias WatchClubWeb.Components.Contents.{EpisodeWatchProgressBadge, SeasonWatchProgressBadge}

  attr :details, TvDetailsResponse, required: true
  attr :selected_season, :integer, required: true
  attr :season_metadata_by_number, :map, required: true
  attr :episodes, :map, required: true, doc: "A 2-levels map of TvShowEpisode by season/ep number"
  attr :current_user, User, required: true

  def episodes_section(assigns) do
    seasons = season_summaries(assigns.details)
    selected = selected_season_summary(seasons, assigns.selected_season)

    assigns =
      assign(assigns,
        seasons: seasons,
        selected_season_summary: selected,
        season_metadata: Map.fetch!(assigns.season_metadata_by_number, selected.season_number)
      )

    ~H"""
    <.card padding="none" class="@container overflow-hidden">
      <div class="flex items-center gap-related p-cluster">
        <span class="inline-flex size-control-md items-center justify-center text-accent">
          <Lucideicons.list_video class="size-icon" />
        </span>
        <h2 class="text-xl font-semibold tracking-tight text-text">
          {dgettext("contents", "Episodes")}
        </h2>
      </div>

      <div class="flex flex-col border-t border-border-subtle @2xl:flex-row">
        <div class="shrink-0 border-b border-border-subtle bg-surface-inset p-tight @2xl:w-32 @2xl:border-r @2xl:border-b-0">
          <.season_selector seasons={@seasons} selected_season={@selected_season} />
        </div>
        <.season_panel
          content_identity={ContentIdentity.for_tv_show(@details.id)}
          current_user={@current_user}
          season_summary={@selected_season_summary}
          season_metadata={@season_metadata}
          season_episodes={Map.get(@episodes, @selected_season, %{})}
          class="min-w-0 flex-1 p-group"
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
      class="flex gap-tight overflow-x-auto @2xl:flex-col"
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
        "min-h-touch-target shrink-0 rounded-md border px-related py-related text-left transition-colors focus-visible:ring-2 focus-visible:ring-focus-ring focus-visible:outline-none @2xl:w-full",
        @selected? && "border-border bg-surface-selected text-text shadow-card",
        !@selected? && "border-transparent text-text-muted hover:bg-surface-hover hover:text-text"
      ]}
    >
      <span class="block text-sm font-semibold">
        {dgettext("contents", "Season %{number}", number: @season.season_number)}
      </span>
      <span :if={Time.maybe_year(@season.air_date)} class="text-xs">
        {Time.maybe_year(@season.air_date)}
      </span>
    </button>
    """
  end

  attr :content_identity, ContentIdentity, required: true
  attr :season_summary, :map, required: true
  attr :season_metadata, :map, required: true
  attr :season_episodes, :map, required: true, doc: "A map of TvShowEpisode by episode number"
  attr :current_user, User, required: true
  attr :class, :any, default: nil

  defp season_panel(assigns) do
    ~H"""
    <div
      id="tv-show-season-panel"
      role="tabpanel"
      aria-labelledby={"tv-show-season-tab-#{@season_summary.season_number}"}
      aria-busy={@season_metadata.status not in [:loaded, :failed]}
      class={["flex flex-col gap-cluster", @class]}
    >
      <.season_panel_body
        content_identity={@content_identity}
        current_user={@current_user}
        season_summary={@season_summary}
        season_metadata={@season_metadata}
        season_episodes={@season_episodes}
      />
    </div>
    """
  end

  attr :content_identity, ContentIdentity, required: true
  attr :season_summary, :map, required: true
  attr :season_metadata, :map, required: true
  attr :current_user, User, required: true
  attr :season_episodes, :map, required: true, doc: "A map of TvShowEpisode by episode number"

  defp season_panel_body(%{season_metadata: %{status: :loaded}} = assigns) do
    assigns =
      assigns
      |> assign(
        season_watch_status:
          season_watch_status(
            assigns.season_episodes,
            length(assigns.season_metadata.details.episodes)
          )
      )

    ~H"""
    <section class="flex flex-col gap-group @xl:flex-row @xl:items-center">
      <.tmdb_poster
        path={@season_metadata.details.poster_path}
        size="w342"
        alt=""
        class="w-32 shrink-0 border border-border-subtle bg-surface-raised"
      />

      <div class="flex flex-col gap-related">
        <.live_component
          id={"season-progress-badge-#{@season_metadata.details.season_number}"}
          module={SeasonWatchProgressBadge}
          status={@season_watch_status}
          content_identity={@content_identity}
          season_number={@season_metadata.details.season_number}
          current_user={@current_user}
        />
        <div class="flex flex-wrap items-center gap-related">
          <h3 class="text-2xl font-semibold tracking-tight text-text">
            {dgettext("contents", "Season %{number}", number: @season_metadata.details.season_number)}
          </h3>
          <span
            :if={Time.maybe_year(@season_metadata.details.air_date)}
            class="text-sm text-text-muted"
          >
            {Time.maybe_year(@season_metadata.details.air_date)}
          </span>
        </div>
        <p
          :if={@season_metadata.details.overview}
          class="line-clamp-3 text-sm leading-6 text-text-muted"
        >
          {@season_metadata.details.overview}
        </p>
        <div
          :if={@season_metadata.details.vote_average}
          class="flex items-center gap-tight text-sm text-text-muted"
        >
          <Lucideicons.star class="size-icon-sm text-success" />
          {format_score(@season_metadata.details.vote_average)}
        </div>
      </div>
    </section>

    <div class="flex flex-col gap-related">
      <.episode_row
        :for={episode_details <- @season_metadata.details.episodes}
        episode={Map.get(@season_episodes, episode_details.episode_number)}
        content_identity={@content_identity}
        episode_details={episode_details}
        current_user={@current_user}
      />
    </div>
    """
  end

  defp season_panel_body(%{season_metadata: %{status: :failed}} = assigns) do
    ~H"""
    <.empty border={false} class="min-h-[24rem] rounded-md bg-surface-inset">
      <:icon><Lucideicons.cloud_off /></:icon>
      <:title>{dgettext("contents", "Error loading season")}</:title>
      <:description>
        {dgettext("contents", "We couldn't load the season. Please try again")}
      </:description>
      <.button
        id={"tv-show-season-retry-button-#{@season_summary.season_number}"}
        phx-click="retry_season_metadata"
        phx-value-season={@season_summary.season_number}
        variant="secondary"
        size="sm"
      >
        <:icon><Lucideicons.refresh_ccw /></:icon>
        {dgettext("contents", "Try again")}
      </.button>
    </.empty>
    """
  end

  defp season_panel_body(assigns) do
    ~H"""
    <span class="sr-only">{dgettext("contents", "Loading season episodes")}</span>
    <section class="flex flex-col gap-group @xl:flex-row @xl:items-center">
      <div class="aspect-2/3 w-32 shrink-0 animate-pulse rounded-md border border-border-subtle bg-surface-raised">
      </div>
      <div class="flex flex-col gap-related">
        <div class="h-8 w-48 animate-pulse rounded-full bg-surface-raised"></div>
        <div class="h-4 w-full max-w-readable animate-pulse rounded-full bg-surface-raised"></div>
        <div class="h-4 w-4/5 max-w-readable animate-pulse rounded-full bg-surface-raised"></div>
      </div>
    </section>

    <div class="flex flex-col gap-related">
      <div
        :for={_index <- episode_skeleton_indexes(@season_summary.episode_count)}
        class="flex flex-col gap-group rounded-md border border-border bg-surface p-related shadow-card @xl:flex-row"
      >
        <div class="aspect-video w-full shrink-0 self-start animate-pulse rounded-md border border-border-subtle bg-surface-raised @xl:w-48">
        </div>
        <div class="flex flex-1 flex-col gap-related">
          <div class="h-5 w-3/5 animate-pulse rounded-full bg-surface-raised"></div>
          <div class="h-4 w-full animate-pulse rounded-full bg-surface-raised"></div>
          <div class="h-4 w-4/5 animate-pulse rounded-full bg-surface-raised"></div>
        </div>
      </div>
    </div>
    """
  end

  attr :content_identity, ContentIdentity, required: true
  attr :episode_details, SeasonDetails.Episode, required: true
  attr :current_user, User, required: true
  attr :episode, TvShowEpisode

  defp episode_row(assigns) do
    assigns =
      assigns
      |> assign(
        watch_status: (assigns.episode && assigns.episode.actor_progress_status) || :not_started
      )

    ~H"""
    <article class="flex flex-col gap-group rounded-md border border-border bg-surface p-related shadow-card @xl:flex-row">
      <.tmdb_still
        size="w300"
        path={@episode_details.still_path}
        class="w-full shrink-0 self-start rounded-md @xl:w-48"
      >
        <.link
          :if={@episode && @episode.has_media?}
          id={"#{@episode_details.id}-episode-play"}
          href={Url.player_link(@episode)}
          aria-label={dgettext("contents", "Play")}
          class="absolute inset-0 flex items-center justify-center"
        >
          <span class="flex size-12 items-center justify-center rounded-full bg-primary text-on-primary shadow-overlay">
            <Lucideicons.play class="size-icon" />
          </span>
        </.link>
      </.tmdb_still>

      <div class="flex min-w-0 flex-1 flex-col gap-related justify-between">
        <div class="flex flex-col gap-tight">
          <div class="flex items-start justify-between gap-related">
            <div class="flex min-w-0 items-center gap-related">
              <.badge variant="accent">
                S{pad(@episode_details.season_number)}E{pad(@episode_details.episode_number)}
              </.badge>
              <h4 class="shrink min-w-0 text-lg leading-tight font-semibold text-text truncate">
                {@episode_details.name}
              </h4>
            </div>

            <.live_component
              id={"episode-progress-badge-#{@episode_details.id}"}
              module={EpisodeWatchProgressBadge}
              status={@watch_status}
              content_identity={@content_identity}
              season_number={@episode_details.season_number}
              episode_number={@episode_details.episode_number}
              current_user={@current_user}
            />
          </div>

          <p :if={@episode_details.overview} class="text-sm leading-6 text-text-muted line-clamp-2">
            {@episode_details.overview}
          </p>
        </div>
        <div
          :if={format_runtime(@episode_details.runtime)}
          class="flex items-center gap-tight text-sm text-text-subtle"
        >
          <Lucideicons.clock class="size-icon-sm" />
          {format_runtime(@episode_details.runtime)}
        </div>
      </div>
    </article>
    """
  end

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

  # Compute the watch status of a tv show season for the current user
  # The season is considered completed if all its episodes are completed,
  # it's in progress if some episodes are in progress or not watched,
  # and it is not_started if none of the episodes are started
  # Episodes is a 2 levels map of season number to episode number to TvShowEpisode.
  # Seasons or Episodes can be missing if they don't exist in DB, in which case
  # they should be considered not started.
  defp season_watch_status(episodes, total_episodes) do
    statuses =
      episodes
      |> Map.values()
      |> Enum.map(& &1.actor_progress_status)

    cond do
      Enum.count(statuses, &(&1 == :completed)) == total_episodes -> :completed
      Enum.all?(statuses, &(&1 == :not_started)) -> :not_started
      true -> :in_progress
    end
  end
end
