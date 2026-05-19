defmodule WatchClubWeb.Contents.TvShowDetailsPage do
  use WatchClubWeb, :live_view

  require Logger

  import WatchClubWeb.Components.Contents.TmdbBackdrop
  import WatchClubWeb.Contents.TvShowDetailsPage.EpisodesSection
  import WatchClubWeb.Contents.TvShowDetailsPage.HeroPanel

  alias WatchClub.Accounts.UserLocale
  alias WatchClub.Contents.ContentView
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse

  @impl true
  def render(%{tv_show: %ContentView{details: %TvDetailsResponse{}}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      class="!p-0"
      space="none"
    >
      <.tv_show_details
        tv_show={@tv_show}
        current_user={@current_user}
        selected_season={@selected_season}
        season_metadata_by_number={@season_metadata_by_number}
      />
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}>
      <.empty>
        <:icon><Lucideicons.tv /></:icon>
        <:title>{dgettext("contents", "TV Show unavailable")}</:title>
        <:description>
          {dgettext("contents", "We could not load this TV Show. Try again later.")}
        </:description>
      </.empty>
    </Layouts.app>
    """
  end

  attr :tv_show, ContentView, required: true
  attr :current_user, User, required: true
  attr :selected_season, :integer, required: true
  attr :season_metadata_by_number, :map, required: true

  defp tv_show_details(assigns) do
    ~H"""
    <article
      aria-labelledby="tv-show-details-title"
      class="relative min-h-[calc(100svh-var(--wc-size-row-lg))] overflow-hidden bg-canvas"
    >
      <.tmdb_backdrop
        :if={@tv_show.details.backdrop_path}
        path={@tv_show.details.backdrop_path}
        size="w1280"
        alt=""
        aria-hidden="true"
        class="absolute inset-0 h-full w-full object-cover opacity-35"
      />
      <div
        aria-hidden="true"
        class="absolute inset-0 bg-linear-to-r from-canvas via-canvas/82 to-canvas/45"
      >
      </div>
      <div
        aria-hidden="true"
        class="absolute inset-0 bg-linear-to-b from-canvas/10 via-canvas/82 to-canvas"
      >
      </div>
      <div
        aria-hidden="true"
        class="absolute inset-0 bg-[radial-gradient(circle_at_28%_18%,var(--wc-color-primary-bg),transparent_34rem)]"
      >
      </div>

      <div class="relative z-1 mx-auto grid w-full max-w-[100rem] grid-cols-1 gap-cluster px-page pb-page-y pt-section 2xl:grid-cols-[minmax(0,1fr)_22rem] 2xl:items-start">
        <.hero_panel tv_show={@tv_show} current_user={@current_user} available?={false} />

        <div class="grid gap-cluster">
          <.section
            :if={@tv_show.details.overview}
            title={dgettext("contents", "Overview")}
            icon={:tv}
          >
            <p class="leading-7 text-text-muted">
              {@tv_show.details.overview}
            </p>
          </.section>

          <.episodes_section
            :if={season_summaries(@tv_show.details) != []}
            details={@tv_show.details}
            selected_season={@selected_season}
            season_metadata_by_number={@season_metadata_by_number}
            locale={@current_user.settings.locale}
          />

          <.section
            :if={cast_and_crew(@tv_show.details) != []}
            title={dgettext("contents", "Cast")}
            icon={:users}
          >
            <ul class="flex max-h-[calc(33.5rem+var(--wc-space-group)+var(--wc-space-tight))] flex-wrap justify-center gap-group overflow-hidden sm:max-h-[calc(36.5rem+var(--wc-space-group)+var(--wc-space-tight))] sm:justify-start">
              <.cast_card :for={person <- cast_and_crew(@tv_show.details)} person={person} />
            </ul>
          </.section>
        </div>

        <aside
          aria-label={"#{dgettext("contents", "Reviews")} / #{dgettext("contents", "External links")}"}
          class="grid content-start gap-cluster"
        >
          <.reviews_card
            :if={format_score(@tv_show.details.vote_average)}
            score={format_score(@tv_show.details.vote_average)}
            score_percent={score_percent(@tv_show.details.vote_average)}
            vote_count={format_vote_count(@tv_show.details.vote_count, @current_user.settings.locale)}
            raw_vote_count={@tv_show.details.vote_count}
          />
          <.external_links_card
            :if={external_links(@tv_show.details) != []}
            links={external_links(@tv_show.details)}
          />
        </aside>
      </div>
    </article>
    """
  end

  attr :score, :string, required: true
  attr :score_percent, :integer, required: true
  attr :vote_count, :string, default: nil
  attr :raw_vote_count, :integer, default: nil

  defp reviews_card(assigns) do
    ~H"""
    <.section title={dgettext("contents", "Reviews")} icon={:star}>
      <div class="grid place-items-center gap-related text-center">
        <div
          class="grid size-24 place-items-center rounded-full p-1"
          style={"background: conic-gradient(var(--wc-color-success) #{@score_percent}%, var(--wc-color-surface-inset) 0)"}
        >
          <div class="grid size-full place-items-center rounded-full bg-surface-overlay">
            <div>
              <p class="text-2xl font-semibold text-text">{@score}</p>
              <p class="text-xs text-text-muted">TMDB</p>
            </div>
          </div>
        </div>
        <p :if={@vote_count && @raw_vote_count} class="text-sm leading-6 text-text-muted">
          {dngettext(
            "contents",
            "Based on %{count} TMDB vote.",
            "Based on %{count} TMDB votes.",
            @raw_vote_count,
            count: @vote_count
          )}
        </p>
      </div>
    </.section>
    """
  end

  attr :links, :list, required: true

  defp external_links_card(assigns) do
    ~H"""
    <.section title={dgettext("contents", "External links")} icon={:external_link}>
      <ul class="grid gap-related">
        <li :for={link <- @links}>
          <.external_link_button link={link} />
        </li>
      </ul>
    </.section>
    """
  end

  attr :person, :map, required: true

  defp cast_card(assigns) do
    ~H"""
    <li class="grid w-28 shrink-0 grid-rows-[10.5rem_6.25rem] overflow-hidden rounded-card border border-border-subtle bg-surface-inset shadow-card sm:w-32 sm:grid-rows-[12rem_6.25rem]">
      <div class="relative bg-surface-raised">
        <img
          :if={@person.profile_path}
          src={tmdb_profile_url(@person.profile_path)}
          alt=""
          class="absolute inset-0 h-full w-full object-cover"
        />
        <div
          :if={!@person.profile_path}
          class="absolute inset-0 grid place-items-center text-lg font-semibold text-accent"
        >
          {@person.initials}
        </div>
      </div>
      <div class="grid content-start gap-tight overflow-hidden p-related">
        <p class="text-sm leading-5 font-semibold break-words text-text">{@person.name}</p>
        <p class="line-clamp-1 text-xs leading-5 break-words text-text-muted">{@person.role}</p>
      </div>
    </li>
    """
  end

  attr :link, :map, required: true

  defp external_link_button(assigns) do
    ~H"""
    <.button
      id={"tv-show-details-link-#{@link.id}"}
      href={@link.url}
      target="_blank"
      variant="secondary"
      class="w-full justify-between"
    >
      {@link.label}
      <:icon position="end"><Lucideicons.external_link /></:icon>
    </.button>
    """
  end

  @impl true
  @spec mount(map(), any(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"tmdb_id" => tmdb_id}, _session, socket) do
    user = socket.assigns.current_user

    case Contents.get_tv_show_details(tmdb_id, actor: user) do
      {:ok, tv_show} ->
        season_summaries = season_summaries(tv_show.details)

        socket =
          socket
          |> assign(:tv_show, tv_show)
          |> assign(:selected_season, default_season(tv_show))
          |> assign(
            :season_metadata_by_number,
            initial_season_metadata_by_number(season_summaries)
          )
          |> start_season_metadata_loads(season_summaries)

        {:ok, socket}

      {:error, error} ->
        Logger.warning("Error loading TV Show: #{inspect(error)}")
        {:ok, socket}
    end
  end

  @impl true
  def handle_info({:content_libraries_updated, %ContentView{} = tv_show}, socket) do
    {:noreply, assign(socket, :tv_show, tv_show)}
  end

  @impl true
  def handle_async({:season_metadata, season_number}, {:ok, {:ok, season_details}}, socket) do
    {:noreply,
     socket
     |> finish_season_metadata_load(season_number, %{status: :loaded, details: season_details})}
  end

  def handle_async({:season_metadata, season_number}, {:ok, {:error, error}}, socket) do
    Logger.warning("Error loading TV Show season metadata: #{inspect(error)}")

    {:noreply,
     socket
     |> finish_season_metadata_load(season_number, %{status: :failed, error: error})}
  end

  def handle_async({:season_metadata, season_number}, {:exit, reason}, socket) do
    Logger.warning("Error loading TV Show season metadata: #{inspect(reason)}")

    {:noreply,
     socket
     |> finish_season_metadata_load(season_number, %{status: :failed, error: reason})}
  end

  @impl true
  def handle_event("select_season", %{"season" => season}, socket) do
    {:noreply, assign(socket, :selected_season, String.to_integer(season))}
  end

  def handle_event("retry_season_metadata", %{"season" => season}, socket) do
    season_number = String.to_integer(season)

    {:noreply,
     socket
     |> put_season_metadata(season_number, %{status: :loading})
     |> start_season_metadata_load(season_number)}
  end

  defp initial_season_metadata_by_number(season_summaries) do
    Map.new(season_summaries, fn season -> {season.season_number, %{status: :loading}} end)
  end

  defp finish_season_metadata_load(socket, season_number, metadata) do
    put_season_metadata(socket, season_number, metadata)
  end

  defp put_season_metadata(socket, season_number, metadata) do
    update(socket, :season_metadata_by_number, &Map.put(&1, season_number, metadata))
  end

  defp start_season_metadata_loads(socket, season_summaries) do
    Enum.reduce(season_summaries, socket, fn season, socket ->
      start_season_metadata_load(socket, season.season_number)
    end)
  end

  defp start_season_metadata_load(socket, season_number) do
    tmdb_id = socket.assigns.tv_show.external_id
    actor = socket.assigns.current_user

    start_async(socket, {:season_metadata, season_number}, fn ->
      Contents.get_tv_show_season_details(tmdb_id, season_number, actor: actor)
    end)
  end

  defp default_season(%ContentView{details: %TvDetailsResponse{} = details}) do
    case season_summaries(details) do
      [season | _] -> season.season_number
      [] -> 1
    end
  end

  defp default_season(_), do: 1

  defp season_summaries(%TvDetailsResponse{} = details) do
    details.seasons
    |> Enum.filter(&(&1.season_number >= 1 and &1.episode_count > 0))
    |> Enum.sort_by(& &1.season_number)
  end

  defp format_score(score) when is_number(score) do
    score
    |> Kernel.*(1.0)
    |> :erlang.float_to_binary(decimals: 1)
  end

  defp format_score(_), do: nil

  defp score_percent(score) when is_number(score) do
    score
    |> Kernel.*(10)
    |> round()
    |> max(0)
    |> min(100)
  end

  defp score_percent(_), do: 0

  defp format_vote_count(nil, _locale), do: nil

  defp format_vote_count(count, locale) do
    WatchClub.Cldr.Number.to_string!(count, locale: UserLocale.to_cldr_locale_name(locale))
  end

  defp cast_and_crew(%TvDetailsResponse{} = details) do
    credits = details.credits
    cast = (credits && credits.cast) || []

    cast
    |> Enum.sort_by(&(&1.order || 999_999))
    |> Enum.take(18)
    |> Enum.map(fn credit ->
      %{
        name: credit.name,
        role: credit.character || credit.job,
        initials: initials(credit.name),
        profile_path: credit.profile_path
      }
    end)
  end

  defp initials(nil), do: nil

  defp initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
  end

  defp external_links(%TvDetailsResponse{} = details) do
    [
      details.external_ids.imdb_id &&
        %{
          id: "imdb",
          label: "IMDb",
          url: "https://www.imdb.com/title/#{details.external_ids.imdb_id}"
        },
      %{
        id: "tmdb",
        label: "TMDB",
        url: "https://www.themoviedb.org/tv/#{details.id}"
      },
      present_url(details.homepage) &&
        %{
          id: "official-site",
          label: dgettext("contents", "Official site"),
          url: details.homepage
        }
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp present_url(nil), do: nil
  defp present_url(""), do: nil
  defp present_url(url), do: url

  defp tmdb_profile_url(path), do: "https://image.tmdb.org/t/p/w185#{path}"
end
