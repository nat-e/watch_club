defmodule WatchClubWeb.Live.Home.ContinueWatching do
  @moduledoc """
  The Contents in progress on the Home page: the latest one in the spotlight, the others in Up next.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.{TmdbBackdrop, TmdbPoster}

  alias WatchClub.Contents.TvShowEpisode

  attr :content, Content, required: true
  attr :locale, :atom, required: true

  # The latest Content in progress, edge to edge. The image fades on the left and at the bottom so
  # the text stays readable. The section is the container, so its height sits on an inner div.
  def spotlight(assigns) do
    assigns = assign(assigns, :playable, playable(assigns.content))

    ~H"""
    <section aria-labelledby="spotlight-label spotlight-title" class="@container">
      <div class="relative isolate flex min-h-[28rem] items-end overflow-hidden @xl:h-[min(70svh,44rem)]">
        <.tmdb_backdrop
          :if={image(@playable)}
          path={image(@playable)}
          size="w1280"
          aria-hidden="true"
          class="absolute inset-0 -z-10 h-full w-full object-cover object-top"
        />
        <div
          aria-hidden="true"
          class="absolute inset-0 -z-10 bg-linear-to-r from-canvas via-canvas/60 to-transparent"
        >
        </div>
        <div
          aria-hidden="true"
          class="absolute inset-x-0 bottom-0 -z-10 h-1/2 bg-linear-to-t from-canvas to-transparent"
        >
        </div>
        <div class="mx-auto w-full max-w-layout-page px-page pb-cluster">
          <div class="flex max-w-xl flex-col items-start gap-group">
            <div class="flex flex-col gap-related">
              <.text_label
                id="spotlight-label"
                text={dgettext("home", "Continue watching")}
                class="font-heading text-text-muted!"
              />
              <h2
                id="spotlight-title"
                class="text-3xl font-semibold tracking-tight text-text @xl:text-5xl"
              >
                <.link
                  navigate={Url.content_details_link(@content)}
                  class="decoration-text-subtle decoration-2 underline-offset-4 hover:underline"
                >
                  {title(@content)}
                </.link>
              </h2>
              <div class="flex items-center gap-related text-sm text-text-muted">
                <span :if={episode_number(@playable)} class="font-semibold tracking-wider uppercase">
                  {episode_number(@playable)}
                </span>
                <.progress_bar
                  :if={@playable.actor_progress}
                  progress={@playable.actor_progress.percent_watched}
                  class="w-24 rounded-full"
                />
                <span>{status(@playable, @locale)}</span>
              </div>
            </div>
            <.button
              id="spotlight-resume"
              variant="primary"
              size="lg"
              navigate={@playable.has_media? && Url.player_link(@playable)}
              disabled={!@playable.has_media?}
              aria-label={dgettext("home", "Resume %{title}", title: title(@content))}
              class="min-w-40"
            >
              <:icon><Lucideicons.play /></:icon>
              {dgettext("home", "Resume")}
            </.button>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :contents, :list, required: true
  attr :locale, :atom, required: true

  def up_next(assigns) do
    ~H"""
    <.section
      surface="transparent"
      padding="none"
      space="group"
      title={dgettext("home", "Up next")}
      class="min-w-0"
    >
      <.scroll_row id="up-next">
        <.up_next_card :for={content <- @contents} content={content} locale={@locale} />
      </.scroll_row>
    </.section>
    """
  end

  attr :content, Content, required: true
  attr :locale, :atom, required: true

  # The whole card is the title link, stretched with ::after, so it has one name and one focus
  # outline, drawn on the card. An unavailable Content links to its page instead of the player.
  defp up_next_card(assigns) do
    assigns = assign(assigns, :playable, playable(assigns.content))

    ~H"""
    <article class="group/card relative flex w-64 shrink-0 snap-start flex-col gap-related rounded-card has-focus-visible:outline-2 has-focus-visible:outline-offset-4 @xl:w-72">
      <div class="relative overflow-hidden rounded-card">
        <.tmdb_still
          path={image(@playable)}
          size="w300"
          class={["w-full", !@playable.has_media? && "opacity-40 grayscale"]}
        />
        <div
          :if={@playable.has_media?}
          class="absolute inset-0 flex items-center justify-center opacity-0 transition-opacity duration-150 group-hover/card:opacity-100 group-has-focus-visible/card:opacity-100 [@media(hover:none)]:opacity-100"
        >
          <span class="flex size-control-lg items-center justify-center rounded-full bg-black/60 text-white">
            <Lucideicons.play class="size-icon-lg" />
          </span>
        </div>
        <.progress_bar
          :if={@playable.actor_progress}
          progress={@playable.actor_progress.percent_watched}
          class="absolute inset-x-0 bottom-0"
        />
      </div>
      <div class="min-w-0">
        <.link
          navigate={
            if @playable.has_media?,
              do: Url.player_link(@playable),
              else: Url.content_details_link(@content)
          }
          aria-label={
            if @playable.has_media?,
              do: dgettext("home", "Resume %{title}", title: title(@content)),
              else: dgettext("home", "%{title}, not available", title: title(@content))
          }
          class="block truncate font-semibold text-text outline-none after:absolute after:inset-0"
        >
          {title(@content)}
        </.link>
        <p class="truncate text-sm text-text-muted">
          {[episode_number(@playable), status(@playable, @locale)]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" · ")}
        </p>
      </div>
    </article>
    """
  end

  attr :progress, :float, required: true, doc: "The progress in %"
  attr :class, :any, default: nil

  defp progress_bar(assigns) do
    ~H"""
    <div class={["h-1 overflow-hidden bg-white/20", @class]}>
      <div class="h-full bg-primary" style={"width: #{@progress}%"}></div>
    </div>
    """
  end

  # What Resume plays: the movie, or the TV show's next episode.
  defp playable(%Content{type: :movie, implementation: movie}), do: movie
  defp playable(%Content{type: :tv_show, implementation: tv_show}), do: tv_show.actor_next_episode

  defp image(%TvShowEpisode{still_path: still_path}), do: still_path
  defp image(movie), do: movie.backdrop_path

  defp episode_number(%TvShowEpisode{formatted_episode_number: number}), do: number
  defp episode_number(_movie), do: nil

  defp title(content), do: content.implementation.best_localization.title

  defp status(%{actor_progress: %WatchProgress{seconds_left: seconds_left}}, locale)
       when is_float(seconds_left),
       do: dgettext("home", "%{time} left", time: Time.pretty_duration(seconds_left, locale))

  defp status(_playable, _locale), do: dgettext("home", "Not started")
end
