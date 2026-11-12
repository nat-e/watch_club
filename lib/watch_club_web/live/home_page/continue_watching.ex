defmodule WatchClubWeb.HomePage.ContinueWatching do
  @moduledoc """
  The User's Continue Watching on Home: the latest one in the spotlight, the others in Up next.
  Resume plays the Movie or the Sports Event, or the TV Show's next TV Show Episode, and the title
  opens the Content's page. Hide sends `hide_from_continue_watching` with its `content_id`.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.{TmdbBackdrop, TmdbPoster}

  @doc "What to load on each Content"
  def content_load do
    [
      :actor_next_medias_to_play,
      :title,
      :backdrop_path,
      implementation: %{
        load: [
          movie: [:actor_progress],
          sports_event: [:actor_progress],
          tv_show: [actor_next_episode: [:actor_progress, :formatted_episode_number]]
        ]
      }
    ]
  end

  attr :content, Content, required: true, doc: "with `content_load/0` loaded"
  attr :locale, :atom, required: true

  # The latest Content in progress, edge to edge. The image fades on the left and at the bottom so
  # the text stays readable. The section is the container, so its height sits on an inner div.
  def spotlight(assigns) do
    assigns = assign(assigns, :playable, playable(assigns.content))

    ~H"""
    <section aria-labelledby="spotlight-label spotlight-title" class="@container">
      <div class="relative isolate flex min-h-[28rem] items-end overflow-hidden @xl:h-[min(70svh,44rem)]">
        <.tmdb_backdrop
          :if={image(@content, @playable)}
          path={image(@content, @playable)}
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
                  percent={@playable.actor_progress.percent_watched}
                  class="w-24 bg-white/20!"
                />
                <span>{status(@playable, @locale)}</span>
              </div>
            </div>
            <div class="flex flex-wrap items-center gap-related">
              <.button
                id="spotlight-resume"
                variant="primary"
                size="lg"
                navigate={play_href(@content)}
                aria-label={dgettext("home", "Resume %{title}", title: title(@content))}
                class="min-w-40"
              >
                <:icon><Lucideicons.play /></:icon>
                {dgettext("home", "Resume")}
              </.button>
              <.button
                id="spotlight-hide"
                variant="overlay"
                size="lg"
                phx-click="hide_from_continue_watching"
                phx-value-content_id={@content.id}
                aria-label={dgettext("home", "Hide %{title}", title: title(@content))}
              >
                <:icon><Lucideicons.eye_off /></:icon>
                {dgettext("home", "Hide")}
              </.button>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :contents, :list, required: true, doc: "with `content_load/0` loaded"
  attr :locale, :atom, required: true

  def up_next(assigns) do
    ids = Enum.map(assigns.contents, & &1.id)

    # Once a card hides, keyboard focus moves to the next card, else to the one before, else to
    # the spotlight's Hide
    focus_after_hide =
      Enum.zip_with([nil | ids], Enum.drop(ids, 1) ++ [nil], fn
        nil, nil -> "#spotlight-hide"
        previous, nil -> "#up-next-#{previous}-resume"
        _previous, next -> "#up-next-#{next}-resume"
      end)

    assigns = assign(assigns, :cards, Enum.zip(assigns.contents, focus_after_hide))

    ~H"""
    <.page_section id="up-next-title" title={dgettext("home", "Up next")}>
      <.scroll_row id="up-next">
        <.up_next_card
          :for={{content, focus_after_hide} <- @cards}
          content={content}
          focus_after_hide={focus_after_hide}
          locale={@locale}
        />
      </.scroll_row>
    </.page_section>
    """
  end

  attr :content, Content, required: true
  attr :focus_after_hide, :string, required: true, doc: "a selector"
  attr :locale, :atom, required: true

  defp up_next_card(assigns) do
    assigns =
      assign(assigns, :playable, playable(assigns.content))

    ~H"""
    <article class="group/card flex w-64 shrink-0 snap-start flex-col gap-related @xl:w-72">
      <div class="relative">
        <.link
          id={"up-next-#{@content.id}-resume"}
          navigate={play_href(@content)}
          aria-label={dgettext("home", "Resume %{title}", title: title(@content))}
          class="group/play relative block overflow-hidden rounded-card"
        >
          <.tmdb_still
            path={image(@content, @playable)}
            size="w300"
            class="w-full"
          />
          <span
            aria-hidden="true"
            class="absolute inset-0 flex items-center justify-center opacity-0 transition-opacity duration-150 group-hover/play:opacity-100 group-focus-visible/play:opacity-100 [@media(hover:none)]:opacity-100"
          >
            <span class="flex size-control-lg items-center justify-center rounded-full bg-black/60 text-white">
              <Lucideicons.play class="size-icon-lg" />
            </span>
          </span>
          <.progress_bar
            :if={@playable.actor_progress}
            percent={@playable.actor_progress.percent_watched}
            class="absolute inset-x-0 bottom-0 rounded-none! bg-white/20!"
          />
        </.link>
        <%!-- On hover and keyboard focus, always on touch screens --%>
        <.button
          id={"up-next-#{@content.id}-hide"}
          variant="secondary"
          size="icon"
          phx-click={
            JS.push("hide_from_continue_watching", value: %{content_id: @content.id})
            |> JS.focus(to: @focus_after_hide)
          }
          aria-label={dgettext("home", "Hide %{title}", title: title(@content))}
          title={dgettext("home", "Hide")}
          class="absolute top-related right-related rounded-full! shadow-overlay opacity-0 transition-opacity duration-150 group-hover/card:opacity-100 focus-visible:opacity-100 pointer-coarse:size-touch-target! [@media(hover:none)]:opacity-100"
        >
          <Lucideicons.eye_off />
        </.button>
      </div>
      <.link
        navigate={Url.content_details_link(@content)}
        class="group/details rounded-control"
      >
        <span class="block truncate font-semibold text-text decoration-text-subtle decoration-2 underline-offset-4 group-hover/details:underline">
          {title(@content)}
        </span>
        <span class="block truncate text-sm text-text-muted">
          {[episode_number(@playable), status(@playable, @locale)]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" · ")}
        </span>
      </.link>
    </article>
    """
  end

  # What Resume plays: the Movie or the Sports Event, or the TV Show's next TV Show Episode
  defp playable(%Content{type: type, implementation: playable})
       when type in [:movie, :sports_event],
       do: playable

  defp playable(%Content{type: :tv_show, implementation: tv_show}), do: tv_show.actor_next_episode

  defp play_href(%Content{actor_next_medias_to_play: medias}), do: Url.player_link(medias)

  # A TV Show Episode's still, else the Content's backdrop
  defp image(_content, %TvShowEpisode{still_path: still_path}), do: still_path
  defp image(content, _playable), do: content.backdrop_path

  defp episode_number(%TvShowEpisode{formatted_episode_number: number}), do: number
  defp episode_number(_movie), do: nil

  defp title(content), do: content.title

  defp status(%{actor_progress: %WatchProgress{seconds_left: seconds_left}}, locale)
       when is_float(seconds_left),
       do: dgettext("home", "%{time} left", time: Time.pretty_duration(seconds_left, locale))

  defp status(_playable, _locale), do: dgettext("home", "Not started")
end
