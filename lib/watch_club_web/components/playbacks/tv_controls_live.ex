defmodule WatchClubWeb.Components.Playbacks.TvControlsLive do
  @moduledoc """
  Play or Pause, 10 seconds back or forward, and the seek bar of the Playback Session playing on
  a TV. They send their commands to the TV, which reports what it did: the Playback Session
  then shows it. Between reports, the seek bar and the times move on in the browser.

  The `bar` layout is the TV bar's: a progress line and Play or Pause until the bar is wide, then
  everything. The `remote` layout is the Remote's.
  """
  use WatchClubWeb, :live_component

  @impl true
  def render(%{layout: "remote"} = assigns) do
    ~H"""
    <div>
      <.playhead id={@id} session={@session} class="flex flex-col gap-group">
        <.seek_bar
          :if={duration(@session)}
          id={"#{@id}-seek-bar"}
          layout="stacked"
          duration={duration(@session)}
          target={@myself}
        />
        <div class="flex items-center justify-center gap-cluster">
          <.seek_button id={"#{@id}-back"} seconds={-10} size="lg" target={@myself} />
          <.play_button
            id={"#{@id}-play"}
            paused?={@session.paused?}
            variant="primary"
            size="icon-lg"
            target={@myself}
            class="[&_svg]:size-icon-lg!"
          />
          <.seek_button id={"#{@id}-forward"} seconds={10} size="lg" target={@myself} />
        </div>
      </.playhead>
    </div>
    """
  end

  def render(%{layout: "bar"} = assigns) do
    ~H"""
    <div class="z-1 flex items-center justify-end @3xl:justify-center">
      <.playhead id={@id} session={@session} class="flex w-full items-center @3xl:flex-col">
        <span
          :if={duration(@session)}
          aria-hidden="true"
          class="absolute inset-x-0 top-0 h-0.5 bg-border @3xl:hidden"
        >
          <span class="block h-full w-(--playhead) bg-primary"></span>
        </span>
        <div class="flex items-center gap-related">
          <.seek_button
            id={"#{@id}-back"}
            seconds={-10}
            size="md"
            target={@myself}
            class="@max-3xl:hidden"
          />
          <.play_button
            id={"#{@id}-play"}
            paused?={@session.paused?}
            variant="ghost"
            size="icon"
            target={@myself}
          />
          <.seek_button
            id={"#{@id}-forward"}
            seconds={10}
            size="md"
            target={@myself}
            class="@max-3xl:hidden"
          />
        </div>
        <.seek_bar
          :if={duration(@session)}
          id={"#{@id}-seek-bar"}
          layout="inline"
          duration={duration(@session)}
          target={@myself}
          class="w-full @max-3xl:hidden"
        />
      </.playhead>
    </div>
    """
  end

  @impl true
  def handle_event("play", _params, socket), do: {:noreply, control(socket, :play)}
  def handle_event("pause", _params, socket), do: {:noreply, control(socket, :pause)}

  def handle_event("skip", %{"seconds" => seconds}, socket) do
    position = NowPlaying.position_now(socket.assigns.session) + String.to_integer(seconds)
    duration = duration(socket.assigns.session)
    {:noreply, control(socket, :seek, position |> max(0.0) |> min(duration))}
  end

  def handle_event("seek", %{"position_seconds" => position}, socket) do
    {position, ""} = Float.parse(position)
    {:noreply, control(socket, :seek, position)}
  end

  # Fails when the TV just stopped, which its notification tells
  defp control(socket, command, position \\ nil) do
    case Playbacks.control_tv(socket.assigns.session, command, %{position_seconds: position},
           actor: socket.assigns.current_user
         ) do
      {:ok, _session} -> socket
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} -> socket
    end
  end

  defp duration(session), do: session.current_playback.media.video.duration_seconds

  attr :id, :string, required: true
  attr :session, Session, required: true
  attr :class, :any, required: true
  slot :inner_block, required: true

  # Where the TV is at, which moves on between its reports: `--playhead`, the times and the seek
  # bar's value. While the seek bar is dragged, they follow it until the TV reports again.
  defp playhead(assigns) do
    duration = duration(assigns.session)
    position = NowPlaying.position_now(assigns.session)

    assigns =
      assign(assigns,
        duration: duration,
        position: position,
        percent: if(duration, do: position / duration * 100, else: 0)
      )

    ~H"""
    <div
      id={"#{@id}-playhead"}
      phx-hook=".Playhead"
      data-position={@position}
      data-duration={@duration}
      data-paused={to_string(@session.paused?)}
      style={"--playhead: #{@percent}%"}
      class={@class}
    >
      {render_slot(@inner_block)}

      <script :type={Phoenix.LiveView.ColocatedHook} name=".Playhead">
        const clock = (seconds) => {
          const total = Math.max(0, Math.floor(seconds))
          const h = Math.floor(total / 3600)
          const m = Math.floor((total % 3600) / 60)
          const s = String(total % 60).padStart(2, "0")
          return h ? `${h}:${String(m).padStart(2, "0")}:${s}` : `${m}:${s}`
        }

        export default {
          mounted() {
            this.el.addEventListener("input", (event) => {
              this.seeking = true
              this.position = Number(event.target.value)
              this.render()
            })
            this.sync()
            this.timer = setInterval(() => this.tick(), 1000)
          },
          updated() { this.sync() },
          destroyed() { clearInterval(this.timer) },
          sync() {
            this.seeking = false
            this.position = Number(this.el.dataset.position)
            this.duration = Number(this.el.dataset.duration)
            this.paused = this.el.dataset.paused === "true"
            this.render()
          },
          tick() {
            if (this.paused || this.seeking) return
            this.position = Math.min(this.position + 1, this.duration || Infinity)
            this.render()
          },
          render() {
            if (!this.duration) return
            this.el.style.setProperty("--playhead", `${(this.position / this.duration) * 100}%`)
            for (const time of this.el.querySelectorAll("[data-playhead='position']"))
              time.textContent = clock(this.position)
            for (const time of this.el.querySelectorAll("[data-playhead='remaining']"))
              time.textContent = `-${clock(this.duration - this.position)}`
            for (const input of this.el.querySelectorAll("input[type='range']"))
              if (!this.seeking) input.value = Math.floor(this.position)
          },
        }
      </script>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :paused?, :boolean, required: true
  attr :variant, :string, required: true
  attr :size, :string, required: true
  attr :target, :any, required: true
  attr :class, :any, default: nil

  defp play_button(assigns) do
    assigns =
      assign(assigns,
        label:
          if(assigns.paused?, do: dgettext("player", "Play"), else: dgettext("player", "Pause"))
      )

    ~H"""
    <.button
      id={@id}
      variant={@variant}
      size={@size}
      phx-click={if @paused?, do: "play", else: "pause"}
      phx-target={@target}
      aria-label={@label}
      title={@label}
      class={["rounded-full!", @class]}
    >
      <Lucideicons.play :if={@paused?} class="fill-current" />
      <Lucideicons.pause :if={!@paused?} class="fill-current" />
    </.button>
    """
  end

  attr :id, :string, required: true
  attr :seconds, :integer, required: true
  attr :size, :string, required: true, values: ~w(md lg)
  attr :target, :any, required: true
  attr :class, :any, default: nil

  # The large one shows the 10 inside its arrow
  defp seek_button(assigns) do
    assigns =
      assign(assigns,
        label:
          if(assigns.seconds < 0,
            do: dgettext("player", "Back 10 seconds"),
            else: dgettext("player", "Forward 10 seconds")
          )
      )

    ~H"""
    <.button
      id={@id}
      variant="ghost"
      size={if @size == "lg", do: "icon-lg", else: "icon"}
      phx-click="skip"
      phx-value-seconds={@seconds}
      phx-target={@target}
      aria-label={@label}
      title={@label}
      class={["relative rounded-full! text-text!", @size == "lg" && "[&_svg]:size-icon-xl!", @class]}
    >
      <Lucideicons.rotate_ccw :if={@seconds < 0} />
      <Lucideicons.rotate_cw :if={@seconds > 0} />
      <span :if={@size == "lg"} class="absolute text-xs font-semibold">10</span>
    </.button>
    """
  end

  attr :id, :string, required: true
  attr :layout, :string, required: true, values: ~w(stacked inline)
  attr :duration, :float, required: true
  attr :target, :any, required: true
  attr :class, :any, default: nil

  # The time played and the time left under or beside it, which the hook fills. A transparent
  # range input over the drawn bar seeks; stacked, it's a touch target high.
  defp seek_bar(assigns) do
    ~H"""
    <div class={[
      "flex text-xs text-text-muted tabular-nums",
      @layout == "stacked" && "flex-col",
      @layout == "inline" && "items-center gap-related",
      @class
    ]}>
      <span :if={@layout == "inline"} data-playhead="position"></span>
      <.form
        for={%{}}
        id={@id}
        layout="none"
        phx-change="seek"
        phx-target={@target}
        class={[
          "relative",
          @layout == "stacked" && "h-touch-target",
          @layout == "inline" && "h-4 flex-1"
        ]}
      >
        <input
          type="range"
          name="position_seconds"
          min="0"
          max={trunc(@duration)}
          step="1"
          phx-debounce="250"
          aria-label={dgettext("player", "Seek")}
          class="peer absolute inset-0 z-1 size-full cursor-pointer opacity-0"
        />
        <span class="absolute inset-x-0 top-1/2 h-1 -translate-y-1/2 rounded-full bg-border">
          <span class="block h-full w-(--playhead) rounded-full bg-primary"></span>
        </span>
        <span class="absolute top-1/2 left-(--playhead) size-3.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-text shadow-overlay peer-focus-visible:ring-2 peer-focus-visible:ring-focus-ring"></span>
      </.form>
      <span :if={@layout == "inline"} data-playhead="remaining"></span>
      <div :if={@layout == "stacked"} class="flex justify-between">
        <span data-playhead="position"></span>
        <span data-playhead="remaining"></span>
      </div>
    </div>
    """
  end
end
