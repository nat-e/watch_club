defmodule WatchClubWeb.Components.Playbacks.TvBar do
  @moduledoc """
  The bar every page docks while the User's Playback Session plays on a TV: above the tabs on
  phones, along the bottom on desktop, as tall as the sidebar's account menu beside it. It opens
  the Remote, and holds its main controls: once wide, in its middle.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClubWeb.Components.Playbacks.TvControlsLive

  attr :id, :string, default: "tv-bar"
  attr :session, Session, required: true, doc: "playing on a TV, with `NowPlaying.fields/0`"
  attr :current_user, User, required: true
  attr :class, :any, default: nil

  def tv_bar(assigns) do
    assigns = assign(assigns, :video, assigns.session.current_playback.media.video)

    ~H"""
    <div
      id={@id}
      class={[
        "@container fixed inset-x-0 bottom-(--wc-tab-bar-height) z-30 overflow-hidden border-t border-border-subtle bg-surface-raised md:bottom-0 md:left-(--wc-sidebar-width)",
        @class
      ]}
    >
      <div class="relative flex h-(--wc-tv-bar-height) items-center gap-group px-related @3xl:grid @3xl:grid-cols-[1fr_var(--container-md)_1fr] @3xl:px-page">
        <.link
          id={"#{@id}-link"}
          navigate={~p"/remote"}
          class="flex min-w-0 flex-1 items-center gap-related rounded-control after:absolute after:inset-0"
        >
          <.tmdb_still
            path={NowPlaying.still_path(@video)}
            size="w185"
            class="w-18 shrink-0 rounded-sm"
          />
          <span class="flex min-w-0 flex-col">
            <span class="truncate text-sm font-semibold">
              {NowPlaying.subtitle(@video) || NowPlaying.title(@video)}
            </span>
            <span class="flex min-w-0 items-center gap-tight text-xs text-text-muted">
              <Lucideicons.cast class="size-icon-sm shrink-0" />
              <span class="truncate">
                {if @session.paused?,
                  do: dgettext("player", "Paused on %{tv}", tv: @session.tv_name),
                  else: @session.tv_name}
              </span>
            </span>
            <span class="sr-only">{dgettext("player", "Open the Remote")}</span>
          </span>
        </.link>
        <.live_component
          module={TvControlsLive}
          id={"#{@id}-controls"}
          session={@session}
          current_user={@current_user}
          layout="bar"
        />
      </div>
    </div>
    """
  end
end
