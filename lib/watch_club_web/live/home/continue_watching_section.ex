defmodule WatchClubWeb.Live.Home.ContinueWatchingSection do
  use WatchClubWeb, :component

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.Content
  alias WatchClub.Shared.Url

  alias WatchClubWeb.Helpers.Time

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

  attr :content, Content, required: true
  attr :current_user, User, required: true

  defp continue_watching_card(%{content: %Content{type: :movie}} = assigns) do
    ~H"""
    <.card>
      <.tmdb_still path={@content.movie.backdrop_path} size="w300" />
      {@content.implementation.best_localization.title}
    </.card>
    """
  end

  defp continue_watching_card(%{content: %Content{type: :tv_show}} = assigns) do
    episode = assigns.content.tv_show.actor_next_episode

    assigns =
      assigns
      |> assign(
        episode: episode,
        time_left:
          episode.actor_progress_status == :in_progress && episode.actor_progress.time_left &&
            Time.pretty_duration(
              episode.actor_progress.time_left,
              assigns.current_user.settings.locale
            )
      )

    ~H"""
    <.card padding="none" class="relative w-80 flex flex-col rounded-lg">
      <div class="relative">
        <.tmdb_still path={@episode.still_path} size="original" class="rounded-t-lg" />
        <.button
          id={"#{@episode.id}-episode-play"}
          variant="primary"
          size="icon-lg"
          class="z-10 absolute inset-0 m-auto rounded-full!"
          disabled={!@episode.has_media?}
          phx-click={
            # Use a click handler to turn this into an HTML Button since links don't handle disabled states
            @episode.has_media? && JS.patch(Url.player_link(@episode))
          }
        >
          <Lucideicons.play />
        </.button>
      </div>
      <.stack space="related" class="m-related">
        <div class="flex justify-between">
          <.link
            href={Url.content_details_link(@content.type, @content.external_id)}
            class="font-semibold text-lg line-clamp-2 min-h-[2lh] after:absolute after:inset-0"
          >
            {@content.implementation.best_localization.title}
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
