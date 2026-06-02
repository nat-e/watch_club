defmodule WatchClubWeb.Contents.MovieDetailsPage do
  use WatchClubWeb, :live_view

  require Logger

  import WatchClubWeb.Components.Contents.TmdbBackdrop
  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Accounts.UserLocale
  alias WatchClub.Contents.ContentView
  alias WatchClub.Integrations.Tmdb.MovieDetailsResponse
  alias WatchClubWeb.Components.Contents.{AddToLibraryButtonLive, PlayOrRequestButtonLive}

  @impl true
  def render(%{movie: %ContentView{details: %MovieDetailsResponse{}}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      class="p-0!"
      space="none"
    >
      <.movie_details movie={@movie} current_user={@current_user} />
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}>
      <.empty>
        <:icon><Lucideicons.film /></:icon>
        <:title>{dgettext("contents", "Movie unavailable")}</:title>
        <:description>
          {dgettext("contents", "We could not load this movie. Try again later.")}
        </:description>
      </.empty>
    </Layouts.app>
    """
  end

  attr :movie, ContentView, required: true
  attr :current_user, User, required: true

  defp movie_details(assigns) do
    details = assigns.movie.details
    locale = assigns.current_user.settings.locale
    in_clubs = ContentView.in_clubs(assigns.movie, assigns.current_user)

    assigns =
      assigns
      |> assign(:in_clubs, in_clubs)
      |> assign(:metadata_items, metadata_items(details))
      |> assign(:primary_country, primary_country(details))
      |> assign(:language_label, original_language_label(details))
      |> assign(:score, format_score(details.vote_average))
      |> assign(:score_percent, score_percent(details.vote_average))
      |> assign(:vote_count, format_vote_count(details.vote_count, locale))
      |> assign(:cast_and_crew, cast_and_crew(details))
      |> assign(:trailer_url, trailer_url(details))
      |> assign(:external_links, external_links(details))

    ~H"""
    <article
      aria-labelledby="movie-details-title"
      class="relative min-h-[calc(100svh-var(--wc-size-row-lg))] overflow-hidden bg-canvas"
    >
      <.tmdb_backdrop
        :if={@movie.details.backdrop_path}
        path={@movie.details.backdrop_path}
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
        <.hero_panel
          movie={@movie}
          current_user={@current_user}
          in_clubs={@in_clubs}
          metadata_items={@metadata_items}
          primary_country={@primary_country}
          language_label={@language_label}
          trailer_url={@trailer_url}
        />

        <div class="grid gap-cluster">
          <.section
            :if={@movie.details.overview}
            title={dgettext("contents", "Overview")}
            icon={:film}
          >
            <p class="leading-7 text-text-muted">
              {@movie.details.overview}
            </p>
          </.section>

          <.section
            :if={@cast_and_crew != []}
            title={dgettext("contents", "Cast")}
            icon={:users}
          >
            <ul class="flex max-h-[calc(33.5rem+var(--wc-space-group)+var(--wc-space-tight))] flex-wrap justify-center gap-group overflow-hidden sm:max-h-[calc(36.5rem+var(--wc-space-group)+var(--wc-space-tight))] sm:justify-start">
              <.cast_card :for={person <- @cast_and_crew} person={person} />
            </ul>
          </.section>
        </div>

        <aside
          aria-label={"#{dgettext("contents", "Reviews")} / #{dgettext("contents", "External links")}"}
          class="grid content-start gap-cluster"
        >
          <.reviews_card
            :if={@score}
            score={@score}
            score_percent={@score_percent}
            vote_count={@vote_count}
            raw_vote_count={@movie.details.vote_count}
          />
          <.external_links_card :if={@external_links != []} links={@external_links} />
        </aside>
      </div>
    </article>
    """
  end

  attr :movie, ContentView, required: true
  attr :current_user, User, required: true
  attr :in_clubs, :list, required: true
  attr :metadata_items, :list, required: true
  attr :primary_country, :map, default: nil
  attr :language_label, :string, required: true
  attr :trailer_url, :string, default: nil

  defp hero_panel(assigns) do
    ~H"""
    <header class="relative flex justify-center py-cluster md:min-h-[32rem] md:py-section xl:min-h-[36rem] 2xl:col-span-2">
      <div class="relative z-1 grid content-start gap-cluster md:min-h-[28rem] xl:min-h-[32rem]">
        <p
          :if={@movie.details.tagline}
          class="justify-self-center text-center text-sm font-semibold tracking-[0.28em] text-accent uppercase"
        >
          {@movie.details.tagline}
        </p>

        <div class="grid content-start gap-cluster md:grid-cols-[11rem_minmax(0,1fr)] md:items-center xl:grid-cols-[15rem_minmax(0,1fr)]">
          <.tmdb_poster
            path={@movie.details.poster_path}
            size="w500"
            alt=""
            class="mx-auto w-44 rounded-card border border-border-subtle shadow-overlay md:mx-0 md:w-full"
          />

          <.stack space="group" class="self-center text-center md:text-left">
            <.stack space="related">
              <h1
                id="movie-details-title"
                class="text-4xl leading-none font-semibold tracking-tight text-text sm:text-5xl xl:text-6xl"
              >
                {@movie.title}
              </h1>

              <ul
                :if={@metadata_items != []}
                class="flex flex-wrap items-center justify-center gap-related text-text-muted md:justify-start"
              >
                <li
                  :for={{item, index} <- Enum.with_index(@metadata_items)}
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
                <span class="font-semibold text-text">{@language_label}</span>
              </li>
              <li
                :if={@primary_country}
                class="inline-flex items-center gap-tight font-semibold text-text"
              >
                <span :if={@primary_country.flag} aria-hidden="true">{@primary_country.flag}</span>
                {@primary_country.name}
              </li>
            </ul>

            <p :if={show_original_title?(@movie, @movie.details)} class="text-center md:text-left">
              {dgettext("contents", "Original title")}:
              <span class="font-semibold text-text">{@movie.details.original_title}</span>
            </p>

            <ul
              :if={@movie.details.genres != []}
              class="flex flex-wrap items-center justify-center gap-related md:justify-start"
            >
              <li :for={genre <- @movie.details.genres}>
                <.badge variant="secondary">{genre.name}</.badge>
              </li>
            </ul>
          </.stack>
        </div>

        <.stack space="group" class="w-full items-center justify-self-center">
          <%!-- <.availability_notice :if={!@available? && @in_clubs == []} movie={@movie} /> --%>
          <.hero_actions
            movie={@movie}
            current_user={@current_user}
            trailer_url={@trailer_url}
          />
        </.stack>
      </div>
    </header>
    """
  end

  attr :movie, ContentView, required: true

  defp availability_notice(assigns) do
    ~H"""
    <div class="mx-auto max-w-readable rounded-card border border-accent-border bg-accent-bg p-group text-left text-sm leading-6 text-accent">
      <div class="flex gap-related">
        <Lucideicons.info class="mt-0.5 size-icon shrink-0 text-accent" />
        <p>
          {dgettext(
            "contents",
            "%{title} is not in your club libraries yet. Add it to a Library so every Member in that club can see it.",
            title: @movie.title
          )}
        </p>
      </div>
    </div>
    """
  end

  attr :movie, ContentView, required: true
  attr :current_user, User, required: true
  attr :trailer_url, :string, default: nil

  defp hero_actions(assigns) do
    ~H"""
    <.cluster class="w-full justify-center">
      <.live_component
        id="movie-details-play-or-request-button"
        module={PlayOrRequestButtonLive}
        content={@movie}
        current_user={@current_user}
        class="w-full md:w-auto"
      />
      <.live_component
        id="movie-details-add-to-library-button"
        module={AddToLibraryButtonLive}
        content={@movie}
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
        id="movie-details-watch-trailer-button"
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
      id={"movie-details-link-#{@link.id}"}
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

    case Contents.get_movie_details(tmdb_id, actor: user) do
      {:ok, movie} ->
        {:ok, socket |> assign(:movie, movie)}

      {:error, error} ->
        Logger.warning("Error loading movie: #{inspect(error)}")
        {:ok, socket}
    end
  end

  @impl true
  def handle_info({:content_libraries_updated, %ContentView{} = movie}, socket) do
    {:noreply, assign(socket, :movie, movie)}
  end

  defp metadata_items(%MovieDetailsResponse{} = details) do
    [
      release_year(details.release_date),
      format_runtime(details.runtime),
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

  defp translated_status("Released"), do: dgettext("contents", "Released")
  defp translated_status(nil), do: nil
  defp translated_status(status), do: status

  defp primary_country(%MovieDetailsResponse{} = details) do
    country = List.first(details.production_countries)
    code = (country && country.iso_3166_1) || List.first(details.origin_country)
    name = (country && country.name) || code

    if name do
      %{name: name, flag: WatchClub.Languages.to_flag(code)}
    end
  end

  defp original_language_label(%MovieDetailsResponse{} = details) do
    details.spoken_languages
    |> Enum.find(&(&1.iso_639_1 == details.original_language))
    |> case do
      %{english_name: english_name} when english_name not in [nil, ""] -> english_name
      %{name: name} when name not in [nil, ""] -> name
      _ -> String.upcase(details.original_language || "")
    end
  end

  defp show_original_title?(%ContentView{title: title}, %MovieDetailsResponse{
         original_title: original_title
       }) do
    original_title not in [nil, ""] and original_title != title
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

  defp cast_and_crew(%MovieDetailsResponse{} = details) do
    credits = details.credits
    cast = (credits && credits.cast) || []
    crew = (credits && credits.crew) || []

    directors =
      crew
      |> Enum.filter(&(&1.job == "Director"))
      |> Enum.take(1)

    actors =
      cast
      |> Enum.sort_by(&(&1.order || 999_999))
      |> Enum.take(17)

    (directors ++ actors)
    |> Enum.uniq_by(&(&1.id || &1.name))
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

  defp trailer_url(%MovieDetailsResponse{} = details) do
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

  defp external_links(%MovieDetailsResponse{} = details) do
    [
      details.imdb_id &&
        %{
          id: "imdb",
          label: "IMDb",
          url: "https://www.imdb.com/title/#{details.imdb_id}"
        },
      %{
        id: "tmdb",
        label: "TMDB",
        url: "https://www.themoviedb.org/movie/#{details.id}"
      },
      present_url(details.homepage) &&
        %{
          id: "official-site",
          label: dgettext("contents", "Official site"),
          url: details.homepage
        },
      %{
        id: "letterboxd-search",
        label: dgettext("contents", "Letterboxd search"),
        url: "https://letterboxd.com/search/#{URI.encode_www_form(details.title || "")}/"
      }
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp present_url(nil), do: nil
  defp present_url(""), do: nil
  defp present_url(url), do: url

  defp tmdb_profile_url(path), do: "https://image.tmdb.org/t/p/w185#{path}"
end
