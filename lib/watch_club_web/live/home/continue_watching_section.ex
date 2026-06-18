defmodule WatchClubWeb.Live.Home.ContinueWatchingSection do
  use WatchClubWeb, :component

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.ContentView
  alias WatchClub.Shared.Url

  import WatchClubWeb.Components.Contents.{ContentTypeBadge, TmdbPoster}

  attr :contents, :list, required: true
  attr :current_user, User, required: true

  def continue_watching_section(assigns) do
    ~H"""
    <.stack space="group">
      <h2 class="">Continue Watching</h2>
      <.cluster>
        <.continue_watching_card
          :for={content <- @contents}
          content={content}
          current_user={@current_user}
        />
      </.cluster>
    </.stack>
    """
  end

  attr :content, ContentView, required: true
  attr :current_user, User, required: true

  defp continue_watching_card(%{content: %ContentView{type: :movie}} = assigns) do
    ~H"""
    <.card>
      <.tmdb_still path={@content.content.movie.backdrop_path} />
      {@content.title}
    </.card>
    """
  end

  defp continue_watching_card(%{content: %ContentView{type: :tv_show}} = assigns) do
    episode = assigns.content.content.tv_show.viewer_next_episode

    assigns =
      assigns
      |> assign(
        episode: episode,
        time_left:
          episode.viewer_progress_status == :in_progress && episode.viewer_progress.time_left &&
            Time.pretty_duration(
              episode.viewer_progress.time_left,
              assigns.current_user.settings.locale
            )
      )

    ~H"""
    <.card padding="none" class="relative w-80 flex flex-col rounded-lg">
      <div>
        <.tmdb_still path={@episode.still_path} size="original" class="rounded-t-lg">
          <.link
            :if={@episode.playable?}
            id={"#{@episode.id}-episode-play"}
            href={Url.player_link(@episode)}
            aria-label="Play"
            class="absolute z-10 inset-0 flex items-center justify-center"
          >
            <span class="flex size-12 items-center justify-center rounded-full bg-primary text-on-primary shadow-overlay">
              <Lucideicons.play class="size-icon" />
            </span>
          </.link>
        </.tmdb_still>
      </div>
      <.stack space="related" class="m-related">
        <div class="flex justify-between">
          <.link
            href={Url.content_details_link(@content.type, @content.external_id)}
            class="font-semibold text-lg line-clamp-2 min-h-[2lh] after:absolute after:inset-0"
          >
            {@content.title}
          </.link>
          <.content_type_badge type={@content.type} />
        </div>
        <.inline class="flex justify-between items-baseline">
          <span class="text-text-muted font-semibold text-sm tracking-wide uppercase ">
            {@episode.formatted_episode_number}
          </span>
          <span class="text-text-subtle font-medium text-sm"></span>
        </.inline>
      </.stack>
    </.card>
    """
  end
end
