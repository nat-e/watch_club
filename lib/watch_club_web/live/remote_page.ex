defmodule WatchClubWeb.RemotePage do
  @moduledoc """
  The Remote: controls the User's Playback Session while it plays on a TV, from any device.
  Compact controls, then Up next and Settings, the audio, subtitles and Quality, as tabs on phones
  and side by side on desktop. `WatchClubWeb.Hooks.PlaybackSession` keeps `@playback_session` up
  to date.

  Its Problem Reports describe what the TV plays, and record the TV's browser.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClubWeb.Components.Playbacks.{ReportProblemLive, TvControlsLive}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      playback_session={@playback_session}
      tv_bar?={false}
      title={(@playback_session && @playback_session.tv_name) || dgettext("player", "Remote")}
      app_bar?={false}
      full_screen?
    >
      <header class="sticky top-0 z-20 bg-canvas">
        <%!-- The TV's name stays centered, with the close button on its left --%>
        <div class="mx-auto grid h-row-lg w-full max-w-5xl grid-cols-[1fr_auto_1fr] items-center gap-related px-tight md:px-page">
          <.button
            id="remote-close"
            phx-hook=".CloseRemote"
            variant="ghost"
            size="icon"
            navigate={~p"/"}
            aria-label={dgettext("player", "Close the Remote")}
            title={dgettext("player", "Close the Remote")}
            class="justify-self-start text-text! max-md:rounded-full! pointer-coarse:size-touch-target!"
          >
            <Lucideicons.chevron_down />
          </.button>
          <script :type={Phoenix.LiveView.ColocatedHook} name=".CloseRemote">
            // Goes back to the page the Remote opened from, when there is one
            export default {
              mounted() {
                this.el.addEventListener("click", (e) => {
                  const canGoBack = window.navigation ? window.navigation.canGoBack : history.length > 1
                  if (!canGoBack || e.metaKey || e.ctrlKey || e.shiftKey) return
                  e.preventDefault()
                  history.back()
                })
              },
            }
          </script>
          <h1 class="flex min-w-0 flex-col items-center text-center">
            <span :if={@playback_session} class="text-xs text-text-muted">
              {if @playback_session.paused?,
                do: dgettext("player", "Paused on"),
                else: dgettext("player", "Playing on")}
            </span>
            <span class="max-w-full truncate text-sm font-semibold">
              {(@playback_session && @playback_session.tv_name) || dgettext("player", "Remote")}
            </span>
          </h1>
        </div>
      </header>

      <div :if={!@playback_session} class="px-page py-section">
        <.empty>
          <:icon><Lucideicons.cast /></:icon>
          <:title>{dgettext("player", "Nothing is playing on a TV")}</:title>
          <:description>
            {dgettext(
              "player",
              "Start a video in Chrome on a computer or an Android phone, then pick a TV with the cast icon in the Player."
            )}
          </:description>
          <.button id="remote-browse" variant="secondary" navigate={~p"/browse"}>
            {dgettext("player", "Browse")}
          </.button>
        </.empty>
      </div>

      <div :if={@playback_session} class="@container">
        <div class="mx-auto flex w-full max-w-5xl flex-col gap-cluster px-page pb-page-y @3xl:flex-row @3xl:items-start @3xl:gap-section">
          <section
            aria-label={dgettext("player", "Now playing")}
            class="flex flex-col gap-group @3xl:sticky @3xl:top-row-lg @3xl:w-sm @3xl:shrink-0"
          >
            <div class="flex items-center gap-group @3xl:flex-col @3xl:items-stretch">
              <.tmdb_still
                path={NowPlaying.still_path(@video)}
                size="original"
                class="w-28 shrink-0 rounded-control @3xl:w-full @3xl:rounded-card @3xl:shadow-card"
              />
              <div class="flex min-w-0 flex-1 flex-col gap-tight">
                <h2 class="truncate font-semibold @3xl:font-heading @3xl:text-2xl">
                  {NowPlaying.title(@video)}
                </h2>
                <p
                  :if={NowPlaying.subtitle(@video)}
                  class="truncate text-sm text-text-muted @3xl:text-base"
                >
                  {NowPlaying.subtitle(@video)}
                </p>
              </div>
            </div>
            <.live_component
              module={TvControlsLive}
              id="remote-controls"
              session={@playback_session}
              current_user={@current_user}
              layout="remote"
            />
            <div class="flex flex-wrap items-center justify-center gap-related">
              <.button
                id="remote-stop"
                variant="secondary"
                size="sm"
                phx-click="stop_casting"
                aria-label={
                  dgettext("player", "Stop casting to %{tv}", tv: @playback_session.tv_name)
                }
                class="pointer-coarse:min-h-touch-target"
              >
                <:icon><Lucideicons.circle_stop /></:icon>
                {dgettext("player", "Stop casting")}
              </.button>
              <.button
                id="remote-report-problem"
                variant="secondary"
                size="sm"
                phx-click="report_problem"
                class="pointer-coarse:min-h-touch-target"
              >
                <:icon><Lucideicons.flag /></:icon>
                {dgettext("player", "Report a problem")}
              </.button>
            </div>
          </section>

          <section
            aria-label={dgettext("player", "More")}
            class="flex min-w-0 flex-1 flex-col gap-cluster"
          >
            <%!-- Tabs on phones only: wide screens show both --%>
            <nav
              :if={@up_next != []}
              aria-label={dgettext("player", "Remote sections")}
              class="flex gap-related @3xl:hidden"
            >
              <.pill
                id="remote-tab-next"
                current={@tab == "next"}
                patch={~p"/remote?tab=next"}
                replace
              >
                {dgettext("player", "Up next")}
              </.pill>
              <.pill
                id="remote-tab-settings"
                current={@tab == "settings"}
                patch={~p"/remote?tab=settings"}
                replace
              >
                {dgettext("player", "Settings")}
              </.pill>
            </nav>
            <.remote_section
              :if={@up_next != []}
              id="remote-up-next"
              title={dgettext("player", "Up next")}
              class={@tab != "next" && "@max-3xl:hidden"}
              tabbed?
            >
              <ul class="-mx-related flex list-none flex-col gap-px p-0">
                <li :for={video <- @up_next}>
                  <button
                    id={"remote-play-#{video.id}"}
                    type="button"
                    phx-click="play"
                    phx-value-media_id={video.id}
                    class="flex w-full items-center gap-group rounded-control p-related text-left transition-colors hover:bg-surface-hover"
                  >
                    <.tmdb_still
                      path={NowPlaying.still_path(video)}
                      size="w300"
                      class="w-28 shrink-0 rounded-control"
                    />
                    <span class="flex min-w-0 flex-1 flex-col gap-tight">
                      <span class="truncate text-sm font-semibold">{NowPlaying.title(video)}</span>
                      <span class="truncate text-xs text-text-muted">
                        {[
                          NowPlaying.episode_number(video),
                          Time.minutes(
                            video.duration_seconds && round(video.duration_seconds / 60),
                            @current_user.settings.locale
                          )
                        ]
                        |> Enum.reject(&is_nil/1)
                        |> Enum.join(" · ")}
                      </span>
                    </span>
                  </button>
                </li>
              </ul>
            </.remote_section>
            <.remote_section
              id="remote-settings"
              title={dgettext("player", "Settings")}
              class={@up_next != [] && @tab != "settings" && "@max-3xl:hidden"}
              tabbed?={@up_next != []}
            >
              <%!-- A single choice shows picked, so the User knows what plays --%>
              <div class="flex flex-col gap-cluster">
                <.choice_chips
                  :if={@video.audio_tracks != []}
                  id="remote-audio"
                  label={dgettext("player", "Audio")}
                  event="pick_audio"
                  playback_id={@playback_session.current_playback.id}
                  choices={Enum.map(@video.audio_tracks, &{&1.id, &1.display_label})}
                  selected={@playback_session.current_playback.audio_track_id}
                />
                <.choice_chips
                  id="remote-subtitles"
                  label={dgettext("player", "Subtitles")}
                  event="pick_subtitles"
                  playback_id={@playback_session.current_playback.id}
                  choices={[
                    {"off", dgettext("player", "Off")}
                    | Enum.map(
                        @playback_session.current_playback.text_track_choices.choices,
                        &{&1.id, @playback_session.current_playback.text_track_choices.names[&1.id]}
                      )
                  ]}
                  selected={@playback_session.current_playback.text_track_id || "off"}
                />
                <.choice_chips
                  id="remote-quality"
                  label={dgettext("player", "Quality")}
                  event="pick_quality"
                  choices={
                    case @playback_session.current_playback.quality_choices.choices do
                      [only] -> [{only, only}]
                      ids -> [{"auto", dgettext("player", "Auto")} | Enum.map(ids, &{&1, &1})]
                    end
                  }
                  selected={
                    case @playback_session.current_playback.quality_choices do
                      %{choices: [only]} -> only
                      %{picked: picked} -> picked || "auto"
                    end
                  }
                />
              </div>
            </.remote_section>
          </section>
        </div>
      </div>
    </Layouts.app>

    <.live_component
      :if={@problem_details}
      module={ReportProblemLive}
      id="report-problem"
      details={@problem_details}
      category={nil}
      current_user={@current_user}
      administrator={@administrator}
      on_close={JS.push("close_problem_report")}
    />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_up_next!()
     |> assign(
       problem_details: nil,
       administrator: Accounts.get_instance_administrator!(actor: socket.assigns.current_user)
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     assign(socket, :tab, Url.parse_url_param(params["tab"], ~w(next settings), "next"))}
  end

  @impl true
  def handle_event("stop_casting", _params, socket) do
    %{playback_session: session, current_user: user} = socket.assigns
    Playbacks.stop_casting!(session, actor: user)

    {:noreply,
     socket
     |> put_flash(:info, dgettext("player", "Stopped casting to %{tv}.", tv: session.tv_name))
     |> push_navigate(to: ~p"/")}
  end

  def handle_event("pick_audio", %{"playback_id" => playback_id, "id" => audio_track_id}, socket) do
    %{current_playback: playback} = socket.assigns.playback_session
    {:noreply, pick_tracks(socket, playback_id, audio_track_id, playback.text_track_id)}
  end

  def handle_event(
        "pick_subtitles",
        %{"playback_id" => playback_id, "id" => text_track_id},
        socket
      ) do
    %{current_playback: playback} = socket.assigns.playback_session
    text_track_id = if text_track_id == "off", do: nil, else: text_track_id
    {:noreply, pick_tracks(socket, playback_id, playback.audio_track_id, text_track_id)}
  end

  # Fails once the Playback Session ended, which its notification tells
  def handle_event("pick_quality", %{"id" => quality}, socket) do
    %{playback_session: session, current_user: user} = socket.assigns
    quality = if quality == "auto", do: nil, else: quality

    case Playbacks.pick_quality(session, quality, actor: user) do
      {:ok, _session} ->
        {:noreply, socket}

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} ->
        {:noreply, socket}
    end
  end

  # What the TV plays, as the Player sends what it shows
  def handle_event("report_problem", _params, socket) do
    %{playback_session: %{current_playback: playback} = session, video: video} = socket.assigns
    audio_track = Enum.find(video.audio_tracks, &(&1.id == playback.audio_track_id))

    details = %{
      "playback_id" => playback.id,
      "position_seconds" => NowPlaying.position_now(session),
      "audio" => audio_track && audio_track.display_label,
      "subtitles" => playback.text_track_choices.names[playback.text_track_id],
      "quality" => playback.quality_choices.picked || dgettext("player", "Auto"),
      "user_agent" => session.tv_user_agent
    }

    {:noreply, assign(socket, :problem_details, details)}
  end

  def handle_event("close_problem_report", _params, socket),
    do: {:noreply, assign(socket, :problem_details, nil)}

  # Plays on the TV, even if it just left: it plays there once it's back
  def handle_event("play", %{"media_id" => media_id}, socket) do
    %{playback_session: session, current_user: user} = socket.assigns
    Playbacks.play!(media_id, session.screen_id, actor: user)
    {:noreply, socket}
  end

  # `WatchClubWeb.Hooks.PlaybackSession` updated `@playback_session` first
  @impl true
  def handle_info(%Notification{resource: Session, action: %{name: action}}, socket)
      when action != :heartbeat,
      do: {:noreply, assign_up_next!(socket)}

  def handle_info({ReportProblemLive, :reported}, socket) do
    {:noreply,
     socket
     |> put_flash(
       :info,
       dgettext("player", "Thanks! We sent your report to %{admin}.",
         admin: socket.assigns.administrator.username
       )
     )
     |> assign(:problem_details, nil)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # Fails for a Playback that's no longer current: the next one started meanwhile
  defp pick_tracks(socket, playback_id, audio_track_id, text_track_id) do
    %{playback_session: session, current_user: user} = socket.assigns

    case Playbacks.pick_tracks(session, playback_id, audio_track_id, text_track_id, actor: user) do
      {:ok, _session} -> socket
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} -> socket
    end
  end

  # The playing Video and the Videos after it, a list intentionally small: at most 10
  defp assign_up_next!(%{assigns: %{playback_session: %Session{} = session}} = socket) do
    %{current_playback: %{media: %{video: video}}} = session
    user = socket.assigns.current_user

    up_next =
      video
      |> Ash.load!(:videos_after, actor: user)
      |> Map.fetch!(:videos_after)
      |> Ash.load!(NowPlaying.video_fields(), actor: user)

    assign(socket, video: video, up_next: up_next)
  end

  defp assign_up_next!(socket), do: assign(socket, video: nil, up_next: [])

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :tabbed?, :boolean, required: true, doc: "on phones, its tab names it"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp remote_section(assigns) do
    ~H"""
    <section aria-labelledby={"#{@id}-heading"} class={["flex flex-col gap-group", @class]}>
      <h2 id={"#{@id}-heading"} class={["text-base font-semibold", @tabbed? && "@max-3xl:sr-only"]}>
        {@title}
      </h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :event, :string, required: true
  attr :playback_id, :string, default: nil, doc: "the Playback of the tracks"
  attr :choices, :list, required: true, doc: "the id and the label of each choice"
  attr :selected, :string, default: nil

  # Main's filter chips: one tap, the picked one in pink, which a tap leaves as it is
  defp choice_chips(assigns) do
    ~H"""
    <div class="flex flex-col gap-related">
      <h3 id={"#{@id}-label"}><.text_label text={@label} /></h3>
      <div role="radiogroup" aria-labelledby={"#{@id}-label"} class="flex flex-wrap gap-related">
        <.filter_chip
          :for={{id, label} <- @choices}
          id={"#{@id}-#{id}"}
          on={id == @selected}
          radio
          phx-click={id != @selected && @event}
          phx-value-playback_id={@playback_id}
          phx-value-id={id}
        >
          {label}
        </.filter_chip>
      </div>
    </div>
    """
  end
end
