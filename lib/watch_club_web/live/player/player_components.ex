defmodule WatchClubWeb.Live.Player.PlayerComponents do
  use WatchClubWeb, :component

  alias WatchClub.MediaCatalog.Calculations.ToPlay

  attr :id, :string, required: true
  attr :label, :string, required: true, doc: "Menu title and trigger aria-label."
  attr :class, :any, default: nil, doc: "The trigger's classes, such as when it shows."
  slot :icon, required: true, doc: "Trigger icon."
  slot :inner_block, required: true, doc: "The menu's items, such as a Video.js radio group."

  slot :submenu, doc: "A view that an item opens with `commandfor` set to its `id`." do
    attr :id, :string, required: true
    attr :label, :string, required: true
  end

  @doc """
  A control-bar dropdown holding Video.js menu items, such as a radio group, and the submenus they
  open. Video.js gives the trigger `data-availability` once its radio group has options.
  """
  def player_menu(assigns) do
    ~H"""
    <button
      type="button"
      commandfor={@id}
      class={[media_menu_button_style(), @class]}
      aria-label={@label}
    >
      {render_slot(@icon)}
    </button>

    <media-menu
      id={@id}
      side="bottom"
      align="end"
      boundary="container"
      class="m-0 w-max min-w-48 max-w-[min(--spacing(72),var(--media-menu-available-width))] max-h-(--media-menu-available-height) overflow-y-auto overscroll-contain rounded-control border border-white/10 bg-black/90 p-tight text-left text-sm text-white shadow-overlay backdrop-blur-sm [--media-popover-boundary-offset:--spacing(2)] [--media-popover-side-offset:--spacing(2)]"
    >
      <media-menu-content class="block outline-none data-child-open:hidden">
        <p class="px-related py-tight text-xs font-semibold uppercase tracking-wider text-white/60">
          {@label}
        </p>
        {render_slot(@inner_block)}
      </media-menu-content>

      <media-menu-content
        :for={submenu <- @submenu}
        id={submenu.id}
        class="block outline-none not-data-open:hidden"
      >
        <%!-- Video.js goes back to the menu from a submenu's first item --%>
        <.player_menu_item>
          <:icon><Lucideicons.chevron_left /></:icon>
          {submenu.label}
        </.player_menu_item>
        {render_slot(submenu)}
      </media-menu-content>
    </media-menu>
    """
  end

  attr :rest, :global, include: ~w(commandfor)
  slot :icon, required: true
  slot :inner_block, required: true

  @doc """
  An item of a `player_menu/1`. With `commandfor`, it opens a submenu and shows what's picked in
  it; Video.js hides it when the submenu has no options.
  """
  def player_menu_item(assigns) do
    ~H"""
    <media-menu-item
      class="flex min-h-touch-target w-full cursor-pointer items-center gap-related rounded-control px-related text-left outline-none data-highlighted:bg-white/20 data-[availability=unavailable]:hidden [&>svg]:size-icon-sm [&>svg]:shrink-0 [&>svg]:text-white/60"
      {@rest}
    >
      {render_slot(@icon)}
      <span class="flex-1 whitespace-nowrap">{render_slot(@inner_block)}</span>
      <span :if={@rest[:commandfor]} data-part="hint" class="min-w-0 truncate text-white/60" />
      <Lucideicons.chevron_right :if={@rest[:commandfor]} />
    </media-menu-item>
    """
  end

  @doc "A single option rendered inside a radio group's <template>."
  def player_radio(assigns) do
    ~H"""
    <media-menu-radio-item class="flex min-h-touch-target w-full cursor-pointer items-center gap-related rounded-control px-related text-left outline-none data-highlighted:bg-white/20">
      <media-menu-item-indicator force-mount class="opacity-0 in-aria-checked:opacity-100">
        <Lucideicons.check class="size-icon-sm" />
      </media-menu-item-indicator>
      <span data-part="label"></span>
    </media-menu-radio-item>
    """
  end

  def seek_bar(assigns) do
    ~H"""
    <media-time-slider
      step="10"
      class="group/timeline relative flex h-10 w-full cursor-pointer touch-none items-center outline-none"
    >
      <media-slider-track class="relative block h-[5px] w-full rounded-full bg-white/20">
        <media-slider-buffer class="absolute inset-y-0 left-0 block w-(--media-slider-buffer) rounded-full bg-white/40" />
        <media-slider-fill class="absolute inset-y-0 left-0 block w-(--media-slider-fill) rounded-full bg-primary" />
      </media-slider-track>
      <media-slider-thumb class="absolute left-(--media-slider-fill) block size-4 -translate-x-1/2 rounded-full bg-white opacity-90 shadow-overlay outline-none ring-white/40 transition-transform group-hover/timeline:scale-125 data-dragging:scale-125 data-dragging:ring-4 focus-visible:ring-2 focus-visible:ring-white/80" />

      <media-slider-preview class="pointer-events-none absolute bottom-full mb-3 flex flex-col items-center gap-tight opacity-0 transition-opacity duration-200 data-pointing:opacity-100 data-dragging:opacity-100">
        <%!-- Video.js scales the sprite tile to fit these min and max sizes --%>
        <media-slider-thumbnail class="block min-h-20 min-w-30 max-h-40 max-w-55 overflow-hidden rounded-md border border-white/10 bg-black shadow-overlay data-hidden:hidden" />
        <media-slider-value
          type="pointer"
          class="rounded-md bg-black/80 px-related py-tight text-xs text-white tabular-nums"
        />
      </media-slider-preview>
    </media-time-slider>
    """
  end

  attr :video, Video, required: true

  def controls_header(assigns) do
    ~H"""
    <header class="flex h-24 items-center gap-related px-related group-data-visible/controls:pointer-events-auto">
      <button
        type="button"
        data-player-command="back"
        class={media_menu_button_style()}
        aria-label={dgettext("player", "Back")}
      >
        <Lucideicons.arrow_left />
      </button>

      <div class="min-w-0 flex-1">
        <h1 class="truncate text-base font-semibold sm:text-xl">
          {NowPlaying.subtitle(@video) || NowPlaying.title(@video)}
        </h1>
      </div>

      <%!-- Phones fold Quality, Audio, Subtitles and Report a problem into Settings --%>
      <div id="player-settings" phx-update="ignore" class="flex shrink-0 items-center gap-tight">
        <.player_menu
          id="player-quality-menu"
          label={dgettext("player", "Quality")}
          class="not-data-availability:hidden @max-xl/player:hidden"
        >
          <:icon><Lucideicons.settings /></:icon>
          <.quality_options />
        </.player_menu>

        <.player_menu
          id="player-audio-menu"
          label={dgettext("player", "Audio")}
          class="not-data-availability:hidden @max-xl/player:hidden"
        >
          <:icon><Lucideicons.languages /></:icon>
          <.audio_options />
        </.player_menu>

        <.player_menu
          id="player-subtitles-menu"
          label={dgettext("player", "Subtitles")}
          class="not-data-availability:hidden @max-xl/player:hidden"
        >
          <:icon><Lucideicons.captions /></:icon>
          <.subtitles_options />
        </.player_menu>

        <%!-- Phones have volume buttons: casting takes its room --%>
        <media-mute-button class={["group/mute pointer-coarse:hidden", media_menu_button_style()]}>
          <Lucideicons.volume_2 class="group-data-muted/mute:hidden" />
          <Lucideicons.volume_x class="hidden group-data-muted/mute:block" />
        </media-mute-button>

        <%!-- Shown by the JS player hook when Chrome finds a TV --%>
        <button
          id="player-cast-button"
          type="button"
          hidden
          data-player-command="cast"
          class={media_menu_button_style()}
          aria-label={dgettext("player", "Play on a TV")}
          title={dgettext("player", "Play on a TV")}
        >
          <Lucideicons.cast />
        </button>

        <media-fullscreen-button class={["group/fullscreen", media_menu_button_style()]}>
          <Lucideicons.maximize class="group-data-fullscreen/fullscreen:hidden" />
          <Lucideicons.minimize class="hidden group-data-fullscreen/fullscreen:block" />
        </media-fullscreen-button>

        <button
          type="button"
          phx-click={report_problem()}
          class={[media_menu_button_style(), "@max-xl/player:hidden"]}
          aria-label={dgettext("player", "Report a problem")}
        >
          <Lucideicons.flag />
        </button>

        <.player_menu
          id="player-settings-menu"
          label={dgettext("player", "Settings")}
          class="@xl/player:hidden"
        >
          <:icon><Lucideicons.settings /></:icon>
          <.player_menu_item commandfor="player-settings-quality">
            <:icon><Lucideicons.settings /></:icon>
            {dgettext("player", "Quality")}
          </.player_menu_item>
          <.player_menu_item commandfor="player-settings-audio">
            <:icon><Lucideicons.languages /></:icon>
            {dgettext("player", "Audio")}
          </.player_menu_item>
          <.player_menu_item commandfor="player-settings-subtitles">
            <:icon><Lucideicons.captions /></:icon>
            {dgettext("player", "Subtitles")}
          </.player_menu_item>
          <.player_menu_item phx-click={report_problem()}>
            <:icon><Lucideicons.flag /></:icon>
            {dgettext("player", "Report a problem")}
          </.player_menu_item>

          <:submenu id="player-settings-quality" label={dgettext("player", "Quality")}>
            <.quality_options />
          </:submenu>
          <:submenu id="player-settings-audio" label={dgettext("player", "Audio")}>
            <.audio_options />
          </:submenu>
          <:submenu id="player-settings-subtitles" label={dgettext("player", "Subtitles")}>
            <.subtitles_options />
          </:submenu>
        </.player_menu>
      </div>
    </header>
    """
  end

  # The Video.js radio groups of the top bar's menus, in their own menu and in Settings

  defp quality_options(assigns) do
    ~H"""
    <media-quality-radio-group>
      <template><.player_radio /></template>
    </media-quality-radio-group>
    """
  end

  defp audio_options(assigns) do
    ~H"""
    <media-audio-track-radio-group>
      <template><.player_radio /></template>
    </media-audio-track-radio-group>
    """
  end

  defp subtitles_options(assigns) do
    ~H"""
    <media-captions-radio-group label={dgettext("player", "Subtitles")}>
      <template><.player_radio /></template>
    </media-captions-radio-group>
    """
  end

  def controls_center_row(assigns) do
    ~H"""
    <div class="pointer-events-none flex items-center justify-center">
      <div
        id="player-playback-controls"
        phx-update="ignore"
        class="flex items-center justify-center gap-related opacity-90 transition-opacity group-data-visible/controls:pointer-events-auto group-has-[media-buffering-indicator[data-visible]]/player:pointer-events-none! group-has-[media-buffering-indicator[data-visible]]/player:opacity-0"
      >
        <media-seek-button
          seconds="-10"
          class={[media_menu_button_style(), "relative size-20! sm:size-24!"]}
        >
          <Lucideicons.rotate_ccw class="size-12! sm:size-16!" />
          <span class="absolute mt-1 text-xs font-semibold">10</span>
        </media-seek-button>

        <media-play-button class={[
          media_menu_button_style(),
          "group/play relative size-24! sm:size-28!"
        ]}>
          <Lucideicons.play class="hidden group-data-paused/play:block size-20! sm:size-24!" />
          <Lucideicons.pause class="group-data-paused/play:hidden size-20! sm:size-24!" />
        </media-play-button>

        <media-seek-button
          seconds="10"
          class={[media_menu_button_style(), "relative size-20! sm:size-24!"]}
        >
          <Lucideicons.rotate_cw class="size-12! sm:size-16!" />
          <span class="absolute mt-1 text-xs font-semibold">10</span>
        </media-seek-button>
      </div>
    </div>
    """
  end

  attr :playback_id, :string, required: true
  attr :video, Video, required: true

  @doc """
  The bottom bar of the Player's controls: the seek bar with its thumbnails, the time, and the
  buttons to the previous and next Part or TV Show Episode.
  """
  def controls_footer(assigns) do
    assigns =
      assign(assigns,
        previous: assigns.video.previous_to_play,
        next: assigns.video.next_to_play
      )

    ~H"""
    <footer class="flex h-24 flex-col gap-related px-group group-data-visible/controls:pointer-events-auto">
      <div id="player-seek-bar" phx-update="ignore">
        <.seek_bar />
      </div>
      <div class="flex items-center justify-center">
        <.button
          :if={@previous}
          id="player-previous-episode-button"
          variant="secondary"
          class="absolute left-group"
          phx-click="play_previous_episode"
          aria-label={dgettext("player", "Play %{name}", name: to_play_name(@previous))}
        >
          <:icon><Lucideicons.skip_back /></:icon>
          {to_play_name(@previous)}
        </.button>
        <.inline
          id="player-time"
          phx-update="ignore"
          space="tight"
          class="relative text-sm text-white/90 tabular-nums has-data-unavailable:invisible"
        >
          <media-time type="current" />
          <span class="text-white/60">/</span>
          <media-time type="duration" />
        </.inline>
        <.button
          :if={@next}
          id="player-next-episode-button"
          variant="secondary"
          class="absolute right-group"
          phx-click="play_next_episode"
          phx-value-playback_id={@playback_id}
          aria-label={dgettext("player", "Play %{name}", name: to_play_name(@next))}
        >
          <:icon><Lucideicons.skip_forward /></:icon>
          {to_play_name(@next)}
        </.button>
      </div>
    </footer>
    """
  end

  attr :playback_id, :string, required: true
  attr :video, Video, required: true

  @doc """
  The Up next prompt. It shows from the start of the Credits, or 5 seconds before the end without
  Credits, and plays the next Part or TV Show Episode after 5 seconds or when the Video ends.
  """
  def up_next_button(assigns) do
    %Video{duration_seconds: duration} = assigns.video

    assigns =
      assign(assigns,
        next: assigns.video.next_to_play,
        from: assigns.video.credits_start_seconds || (duration && duration - 5)
      )

    ~H"""
    <.player_prompt
      :if={@next}
      id="player-up-next-button"
      from={@from}
      data-countdown
      phx-click="play_next_episode"
      phx-value-playback_id={@playback_id}
      class="isolate overflow-hidden"
    >
      <:icon><Lucideicons.skip_forward /></:icon>
      <%!-- The JS player hook sets --countdown from 0 to 1 --%>
      <span
        aria-hidden="true"
        class="absolute inset-y-0 left-0 -z-10 w-[calc(var(--countdown,0)*100%)] bg-primary/40 motion-safe:transition-[width] motion-safe:duration-300 motion-safe:ease-linear"
      />
      {dgettext("player", "Play %{name}", name: to_play_name(@next))}
    </.player_prompt>
    """
  end

  attr :video, Video, required: true

  @doc """
  "Skip intro" and "Skip recap" prompts, revealed during their Marker. They jump to its end.
  """
  def skip_marker_buttons(assigns) do
    ~H"""
    <.player_prompt
      :for={marker <- @video.markers}
      :if={marker.kind in [:intro, :recap]}
      id={"player-skip-#{marker.kind}-button"}
      from={marker.start_seconds}
      until={marker.end_seconds}
      data-skip-to={marker.end_seconds}
    >
      <:icon><Lucideicons.skip_forward /></:icon>
      {if marker.kind == :intro,
        do: dgettext("player", "Skip intro"),
        else: dgettext("player", "Skip recap")}
    </.player_prompt>
    """
  end

  attr :from, :float,
    required: true,
    doc: "When it shows, in seconds of the video. Never when nil."

  attr :until, :float, default: nil, doc: "When it hides again. At the end of the video when nil."
  attr :class, :string, default: nil
  attr :rest, :global
  slot :icon, required: true
  slot :inner_block, required: true

  # A button over the video, bottom right, that the JS player hook reveals from `from` until
  # `until` by setting `data-active`
  defp player_prompt(assigns) do
    ~H"""
    <.button
      variant="secondary"
      data-show-from={@from}
      data-show-until={@until}
      phx-mounted={JS.ignore_attributes(["data-active", "style"])}
      class={
        [
          "invisible absolute bottom-28 right-group z-40 opacity-0 data-active:visible data-active:opacity-100 sm:bottom-32",
          # Out of the way of the seek bar's thumbnail
          "group-has-[media-slider-preview[data-pointing]]/player:invisible group-has-[media-slider-preview[data-dragging]]/player:invisible",
          @class
        ]
      }
      {@rest}
    >
      <:icon>{render_slot(@icon)}</:icon>
      {render_slot(@inner_block)}
    </.button>
    """
  end

  @doc """
  Centered spinner shown whenever the player has no frame to display — the
  initial session load and buffering both render it.
  """
  attr :class, :string, default: nil, doc: "Positioning and visibility of the overlay."

  def player_loader(assigns) do
    ~H"""
    <div class={["pointer-events-none grid place-items-center", @class]} aria-hidden="true">
      <div class="grid size-24 place-items-center rounded-full bg-black/60 backdrop-blur-sm">
        <Lucideicons.loader_circle class="size-14 animate-spin text-white/90" />
      </div>
    </div>
    """
  end

  @doc """
  An full page overlay displayed when there is an error loading media in the player.
  Contains a CTA that redirects to the homepage
  """
  def player_load_error_overlay(assigns) do
    ~H"""
    <.player_overlay id="watch-club-player-error" role="alert" aria-live="assertive">
      <:icon><Lucideicons.triangle_alert /></:icon>
      <:title>{dgettext("player", "Error loading video")}</:title>
      <:description>
        {dgettext("player", "We couldn't find the media you were looking for.")}
      </:description>
      <.button id="player-error-back-button" navigate={~p"/"}>
        {dgettext("player", "Back home")}
      </.button>
      <.button id="player-error-report-button" variant="ghost" phx-click={report_problem()}>
        <:icon><Lucideicons.flag /></:icon>
        {dgettext("player", "Report a problem")}
      </.button>
    </.player_overlay>
    """
  end

  attr :tv_name, :string, required: true

  @doc "Shown over the paused video while the TV connects, until it plays there."
  def cast_connecting_overlay(assigns) do
    ~H"""
    <.player_overlay id="player-cast-connecting" role="status">
      <:icon><Lucideicons.loader_circle class="motion-safe:animate-spin" /></:icon>
      <:title>{dgettext("player", "Connecting to %{tv}…", tv: @tv_name)}</:title>
      <.button id="player-cast-cancel-button" variant="secondary" data-player-command="cancel-cast">
        {dgettext("player", "Cancel")}
      </.button>
    </.player_overlay>
    """
  end

  @doc "Shown instead of the video once another Player plays the Playback Session."
  def playing_elsewhere_overlay(assigns) do
    ~H"""
    <.player_overlay id="player-playing-elsewhere" role="alert">
      <:icon><Lucideicons.monitor_play /></:icon>
      <:title>{dgettext("player", "Playing somewhere else")}</:title>
      <:description>
        {dgettext("player", "You started watching on another screen.")}
      </:description>
      <.button id="player-playing-elsewhere-back-button" navigate={~p"/"}>
        {dgettext("player", "Back home")}
      </.button>
    </.player_overlay>
    """
  end

  attr :id, :string, required: true
  attr :rest, :global, include: ~w(role)
  slot :icon, required: true
  slot :title, required: true
  slot :description
  slot :inner_block, required: true, doc: "its actions"

  # Covers the Player with a message and its actions
  defp player_overlay(assigns) do
    ~H"""
    <div
      id={@id}
      class="absolute inset-0 z-50 grid place-items-center bg-scrim px-page text-center"
      {@rest}
    >
      <.empty class="max-w-panel">
        <:icon>{render_slot(@icon)}</:icon>
        <:title>{render_slot(@title)}</:title>
        <:description :if={@description != []}>{render_slot(@description)}</:description>
        {render_slot(@inner_block)}
      </.empty>
    </div>
    """
  end

  # Asks the Player hook to pause, then to open the form with what the Player shows
  defp report_problem, do: JS.dispatch("player:report-problem", to: "#watch-club-player")

  defp media_menu_button_style,
    do:
      "inline-flex size-10 sm:size-12 [&_svg]:size-6 sm:[&_svg]:size-7 items-center justify-center rounded-md text-white outline-none cursor-pointer hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-white/80"

  # The name of what a button plays: Part 2, or S06E16
  defp to_play_name(%ToPlay{part: %Part{} = part}), do: Parts.name(part)
  defp to_play_name(%ToPlay{episode: episode}), do: episode.formatted_episode_number
end
