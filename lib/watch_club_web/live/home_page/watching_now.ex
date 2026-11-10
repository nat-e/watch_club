defmodule WatchClubWeb.HomePage.WatchingNow do
  @moduledoc """
  Watching Now on Home: the other Users whose Player is active, one line each, with the Content
  and the TV Show Episode it plays.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  attr :watchers, :list,
    required: true,
    doc: "from `Playbacks.list_watching_now`: each one's `user`, `content` and `tv_show_episode`"

  def watching_now(assigns) do
    ~H"""
    <.page_section id="watching-now-title" title={dgettext("home", "Watching now")}>
      <ul class="flex max-w-panel list-none flex-col p-0">
        <.watcher
          :for={watcher <- @watchers}
          user={watcher.user}
          content={watcher.content}
          tv_show_episode={watcher.tv_show_episode}
        />
      </ul>
    </.page_section>
    """
  end

  attr :user, User, required: true
  attr :content, Content, required: true
  attr :tv_show_episode, TvShowEpisode, default: nil

  # The line is the Content's link, stretched with ::after, which describes it with who watches
  defp watcher(assigns) do
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
          aria-describedby={"watching-now-#{@user.id}-who"}
          class="truncate font-semibold text-text after:absolute after:inset-0"
        >
          {@content.title}
        </.link>
        <p id={"watching-now-#{@user.id}-who"} class="truncate text-sm text-text-muted">
          {[@user.username, @tv_show_episode && @tv_show_episode.formatted_episode_number]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" · ")}
        </p>
      </div>
      <.tmdb_poster
        path={@content.poster_path}
        size="w92"
        class="w-10 shrink-0"
      />
    </li>
    """
  end
end
