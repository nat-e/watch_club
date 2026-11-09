defmodule WatchClubWeb.HomePage.WatchingNow do
  @moduledoc """
  Watching Now on Home: the other Users whose Player is active, one line each, with the Content
  and the TV Show Episode it plays.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  @doc "What to load on each Playback Session"
  def session_load do
    [
      :started_by,
      active_playback: [
        media: [content: [:implementation], video: [tv_show_episode: [:formatted_episode_number]]]
      ]
    ]
  end

  attr :sessions, :list, required: true, doc: "with `session_load/0` loaded"

  def watching_now(assigns) do
    ~H"""
    <.page_section id="watching-now-title" title={dgettext("home", "Watching now")}>
      <ul class="flex list-none flex-col p-0">
        <.watcher
          :for={session <- @sessions}
          user={session.started_by}
          media={session.active_playback.media}
        />
      </ul>
    </.page_section>
    """
  end

  attr :user, User, required: true
  attr :media, Media, required: true

  # The line is the Content's link, stretched with ::after
  defp watcher(assigns) do
    assigns = assign(assigns, :content, assigns.media.content)

    ~H"""
    <li id={"watching-now-#{@user.id}"} class="relative flex items-center gap-group py-related">
      <span class="relative shrink-0">
        <.avatar id={@user.id} name={@user.username} size="lg" aria-hidden="true" />
        <span
          aria-hidden="true"
          class="absolute -right-0.5 -bottom-0.5 size-3 rounded-full bg-accent ring-2 ring-canvas"
        ></span>
      </span>
      <div class="flex min-w-0 flex-1 flex-col">
        <.link
          navigate={Url.content_details_link(@content)}
          class="truncate font-semibold text-text after:absolute after:inset-0"
        >
          {@content.implementation.best_localization.title}
        </.link>
        <p class="truncate text-sm text-text-muted">
          {[@user.username, episode_number(@media.video)]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" · ")}
        </p>
      </div>
      <.tmdb_poster
        path={@content.implementation.best_localization.poster_path}
        size="w92"
        class="w-10 shrink-0"
      />
    </li>
    """
  end

  defp episode_number(%Video{tv_show_episode: %TvShowEpisode{formatted_episode_number: number}}),
    do: number

  defp episode_number(_video), do: nil
end
