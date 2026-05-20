defmodule WatchClubWeb.PlayerPage do
  use WatchClubWeb, :live_view

  alias WatchClub.Playback.HlsSession

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-canvas text-text">
      <div
        :if={is_nil(@player_session)}
        class="mx-auto flex min-h-screen max-w-layout-page flex-col gap-section px-page py-page-y"
      >
        <header class="flex flex-col gap-related sm:flex-row sm:items-end sm:justify-between">
          <div class="space-y-related">
            <p class="text-sm font-medium uppercase tracking-wide text-accent">Prototype</p>
            <h1 class="text-3xl font-semibold tracking-tight text-text">WatchClub Web Player</h1>
            <p class="max-w-readable text-sm text-text-muted">
              HLS playback with on-demand transcoding, adaptive renditions, selectable audio, subtitle tracks, disk segment caching, and automatic session cleanup.
            </p>
          </div>
          <.link
            navigate={~p"/"}
            class="inline-flex h-control-md items-center justify-center rounded-control border border-border bg-surface px-group text-sm font-medium text-text hover:bg-surface-hover"
          >
            Back home
          </.link>
        </header>

        <section class="flex min-h-[24rem] items-center justify-center rounded-card border border-border bg-surface p-section shadow-card">
          <div :if={@player_error} class="max-w-readable space-y-related text-center">
            <p class="text-lg font-semibold text-danger">Could not start player session</p>
            <p class="text-sm text-text-muted">{@player_error}</p>
          </div>
          <div :if={is_nil(@player_error)} class="max-w-readable space-y-related text-center">
            <p class="text-lg font-semibold text-text">Starting player…</p>
            <p class="text-sm text-text-muted">Preparing an HLS playback session.</p>
          </div>
        </section>
      </div>

      <div
        :if={@player_session}
        class="mx-auto flex min-h-screen max-w-layout-page flex-col gap-section px-page py-page-y"
      >
        <header class="flex flex-col gap-related sm:flex-row sm:items-end sm:justify-between">
          <div class="space-y-related">
            <p class="text-sm font-medium uppercase tracking-wide text-accent">Prototype</p>
            <h1 class="text-3xl font-semibold tracking-tight text-text">WatchClub Web Player</h1>
            <p class="max-w-readable text-sm text-text-muted">
              HLS playback with on-demand transcoding, adaptive renditions, selectable audio, subtitle tracks, disk segment caching, and automatic session cleanup.
            </p>
          </div>
          <.link
            navigate={~p"/"}
            class="inline-flex h-control-md items-center justify-center rounded-control border border-border bg-surface px-group text-sm font-medium text-text hover:bg-surface-hover"
          >
            Back home
          </.link>
        </header>

        <section
          id="watch-club-player"
          phx-hook="Player"
          phx-update="ignore"
          data-session={Jason.encode!(@player_session)}
          data-hls-src={~p"/assets/js/player_hls.js"}
          class="grid gap-cluster lg:grid-cols-[minmax(0,1fr)_22rem]"
        >
          <div class="overflow-hidden rounded-card border border-border bg-surface shadow-card">
            <div class="bg-black">
              <video
                id="player"
                data-player-video
                class="aspect-video w-full bg-black"
                controls
                playsinline
                preload="metadata"
              >
              </video>
            </div>
            <div class="flex flex-col gap-cluster border-t border-border-subtle p-cluster sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 class="text-lg font-semibold text-text">{@player_session.title}</h2>
                <p class="text-sm text-text-muted">
                  {@player_session.video.width}×{@player_session.video.height} · {format_duration(
                    @player_session.duration
                  )} · source {@player_session.video.codec}
                </p>
              </div>
              <div
                data-player-status
                class="rounded-full border border-info-border bg-info-bg px-related py-tight text-sm font-medium text-info"
              >
                Starting session…
              </div>
            </div>
          </div>

          <aside class="flex flex-col gap-cluster rounded-card border border-border bg-surface p-cluster shadow-card">
            <div class="space-y-related">
              <h2 class="text-lg font-semibold text-text">Playback controls</h2>
              <p class="text-sm text-text-muted">
                Use Auto for adaptive streaming or pin a rendition for low bandwidth testing.
              </p>
            </div>

            <label class="space-y-tight text-sm font-medium text-text">
              <span>Quality</span>
              <select
                data-player-quality
                class="h-control-md w-full rounded-control border border-border bg-surface-inset px-related text-text focus:border-border-focus focus:outline-none focus:ring-2 focus:ring-focus-ring"
              >
                <option>Loading…</option>
              </select>
            </label>

            <label class="space-y-tight text-sm font-medium text-text">
              <span>Audio</span>
              <select
                data-player-audio
                class="h-control-md w-full rounded-control border border-border bg-surface-inset px-related text-text focus:border-border-focus focus:outline-none focus:ring-2 focus:ring-focus-ring"
              >
                <option>Loading…</option>
              </select>
            </label>

            <label class="space-y-tight text-sm font-medium text-text">
              <span>Subtitles</span>
              <select
                data-player-subtitles
                class="h-control-md w-full rounded-control border border-border bg-surface-inset px-related text-text focus:border-border-focus focus:outline-none focus:ring-2 focus:ring-focus-ring"
              >
                <option value="-1">Off</option>
              </select>
            </label>

            <div class="grid grid-cols-2 gap-related">
              <button
                data-player-seek-back
                type="button"
                class="h-control-md rounded-control border border-border bg-surface-raised px-related text-sm font-medium text-text hover:bg-surface-hover"
              >
                −10 sec
              </button>
              <button
                data-player-seek-forward
                type="button"
                class="h-control-md rounded-control border border-border bg-surface-raised px-related text-sm font-medium text-text hover:bg-surface-hover"
              >
                +10 sec
              </button>
            </div>

            <div class="rounded-card border border-border-subtle bg-surface-inset p-group text-sm text-text-muted">
              <dl class="space-y-related">
                <div class="flex justify-between gap-related">
                  <dt>Session</dt>
                  <dd class="font-mono text-text">{@player_session.id}</dd>
                </div>
                <div class="flex justify-between gap-related">
                  <dt>Segments</dt>
                  <dd data-player-cache class="text-text">
                    0 / {@player_session.segment_count} cached
                  </dd>
                </div>
                <div class="flex justify-between gap-related">
                  <dt>Position</dt>
                  <dd data-player-position class="text-text">0:00</dd>
                </div>
              </dl>
            </div>
          </aside>
        </section>
      </div>
    </main>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "WatchClub Player")
      |> assign(:player_session, nil)
      |> assign(:player_error, nil)

    if connected?(socket) do
      Process.flag(:trap_exit, true)
      start_player_session(socket)
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event(
        "player_status",
        _params,
        %{assigns: %{player_session: %{id: session_id}}} = socket
      ) do
    reply =
      case HlsSession.status(session_id) do
        {:ok, status} -> %{ok: true, status: status}
        {:error, :not_found} -> %{ok: false, error: "session not found"}
        {:error, reason} -> %{ok: false, error: inspect(reason)}
      end

    {:reply, reply, socket}
  end

  def handle_event("player_status", _params, socket) do
    {:reply, %{ok: false, error: "session not found"}, socket}
  end

  def handle_event("player_stop", _params, socket) do
    {:reply, stop_player_session(socket.assigns.player_session), socket}
  end

  @impl true
  def terminate(_reason, socket) do
    stop_player_session(socket.assigns[:player_session])
    :ok
  end

  defp start_player_session(socket) do
    case HlsSession.start_session() do
      {:ok, session} -> {:ok, assign(socket, :player_session, session)}
      {:error, reason} -> {:ok, assign(socket, :player_error, inspect(reason))}
    end
  end

  defp stop_player_session(%{id: session_id}) do
    case HlsSession.stop(session_id) do
      :ok -> %{ok: true}
      {:error, :not_found} -> %{ok: true}
      {:error, reason} -> %{ok: false, error: inspect(reason)}
    end
  end

  defp stop_player_session(_session), do: %{ok: true}

  defp format_duration(duration) do
    duration = trunc(duration)
    minutes = div(duration, 60)
    seconds = duration |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{minutes}:#{seconds}"
  end
end
