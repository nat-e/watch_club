defmodule WatchClubWeb.Live.Home.ContinueWatchingSection do
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  attr :contents, :list, required: true
  attr :current_user, User, required: true

  def continue_watching_section(assigns) do
    ~H"""
    <.section
      surface="transparent"
      title="Continue Watching"
      padding="none"
      space="related"
    >
      <.cluster>
        <.continue_watching_card
          :for={content <- @contents}
          content={content}
          current_user={@current_user}
        />
      </.cluster>
    </.section>
    """
  end

  attr :content, Content, required: true
  attr :current_user, User, required: true

  defp continue_watching_card(%{content: %Content{type: :movie}} = assigns) do
    ~H"""
    <.generic_continue_watching_card
      content={@content}
      play_link={(@content.movie.has_media? && Url.player_link(@content.movie)) || nil}
      disabled={!@content.movie.has_media?}
      watch_progress={@content.movie.actor_progress}
      locale={@current_user.settings.locale}
      image={@content.movie.backdrop_path}
    />
    """
  end

  defp continue_watching_card(%{content: %Content{type: :tv_show}} = assigns) do
    assigns = assigns |> assign(episode: assigns.content.tv_show.actor_next_episode)

    ~H"""
    <.generic_continue_watching_card
      content={@content}
      disabled={!@episode.has_media?}
      play_link={(@episode.has_media? && Url.player_link(@episode)) || nil}
      watch_progress={@episode.actor_progress}
      locale={@current_user.settings.locale}
      image={@episode.still_path}
      additional_info={@episode.formatted_episode_number}
    />
    """
  end

  attr :content, Content, required: true
  attr :image, :string, required: true
  attr :play_link, :string, required: true
  attr :watch_progress, WatchProgress
  attr :locale, :atom, required: true
  attr :disabled, :boolean, default: false
  attr :additional_info, :string, default: nil

  defp generic_continue_watching_card(assigns) do
    assigns =
      assigns
      |> assign(
        time_left:
          assigns.watch_progress && assigns.watch_progress.seconds_left &&
            Time.pretty_duration(
              assigns.watch_progress.seconds_left,
              assigns.locale
            )
      )

    ~H"""
    <.card padding="none" class="relative w-60 flex flex-col rounded-lg">
      <div class="relative">
        <.tmdb_still path={@image} size="w300" class="rounded-t-lg" />
        <div class="absolute inset-0 flex items-center justify-center">
          <.button
            :if={!@disabled}
            id={"continue-watching-play-#{@content.id}"}
            variant="primary"
            size="icon-lg"
            class="rounded-full! after:inset-0 after:absolute"
            patch={@play_link}
          >
            <Lucideicons.play />
          </.button>
        </div>
        <.progress_bar
          :if={@watch_progress}
          progress={@watch_progress.percent_watched}
          class="absolute bottom-0"
        />
        <div :if={@disabled} class="absolute inset-0 bg-scrim rounded-t-lg" />
      </div>
      <.stack space="related" class="m-related">
        <div class="flex justify-between">
          <.link
            href={Url.content_details_link(@content.type, @content.external_id)}
            class="z-10 font-semibold text-lg line-clamp-1 hover:underline"
          >
            {@content.implementation.best_localization.title}
          </.link>
        </div>
        <.inline class="flex justify-end">
          <span
            :if={@additional_info}
            class="flex-1 text-text-muted font-semibold text-sm tracking-wide uppercase"
          >
            {@additional_info}
          </span>
          <span :if={@disabled} class="text-text-subtle font-medium text-sm">
            {dgettext("home", "Not available")}
          </span>
          <span :if={!@disabled && @time_left} class="text-text-subtle font-medium text-sm">
            {dgettext("home", "%{time} left", time: @time_left)}
          </span>
          <span :if={!@disabled && !@time_left} class="text-text-subtle font-medium text-sm">
            {dgettext("home", "Not started")}
          </span>
        </.inline>
      </.stack>
    </.card>
    """
  end

  attr :progress, :float, required: true, doc: "The progress in %"
  attr :class, :any, default: nil

  defp progress_bar(assigns) do
    ~H"""
    <div class={["w-full h-1 bg-scrim", @class]}>
      <div
        class="h-full bg-primary"
        style={"width: #{@progress}%"}
      />
    </div>
    """
  end
end
