defmodule WatchClubWeb.TvChannel do
  @moduledoc """
  The TV's side of a Playback Session it plays. Joining makes the TV its Screen. The TV then
  hears what to play and the Remote's commands, and reports where it's at.

  Pushes `state` with what to play, `command` with a command of the Remote, and `stop` once the
  Playback Session ended or plays somewhere else. The TV's reports name the Playback they're
  about, and it reports the errors of Google's receiver framework, which only it sees.

  Counts each join, refusal and drop in the `[:watch_club, :cast]` telemetry event.
  """
  use Phoenix.Channel

  require Logger

  alias Ash.Notifier.Notification
  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.{Playback, Session}
  alias WatchClubWeb.Helpers.{NowPlaying, PlaybackPaths, Url}

  @impl true
  def join("tv", _params, socket) do
    %{cast: cast, user: user} = socket.assigns

    with {:ok, before} <- Playbacks.get_session_by_id(cast.session_id, actor: user),
         {:ok, session} <-
           Playbacks.cast(before, cast.screen_id, cast.tv_name, cast.from_screen_id,
             load: NowPlaying.fields(),
             actor: user
           ) do
      # It takes over from the Player that cast it, or comes back after it dropped
      result = if before.screen_id == cast.from_screen_id, do: :joined, else: :rejoined
      :telemetry.execute([:watch_club, :cast], %{count: 1}, %{result: result})
      Phoenix.PubSub.subscribe(WatchClub.PubSub, "playback_session:#{user.id}")
      Phoenix.PubSub.subscribe(WatchClub.PubSub, "tv:#{session.id}")
      {:ok, state(session), assign(socket, :session, session)}
    else
      _ended_or_playing_elsewhere ->
        :telemetry.execute([:watch_club, :cast], %{count: 1}, %{result: :refused})
        {:error, %{reason: "playing_elsewhere"}}
    end
  end

  # Reports about a Playback that's no longer current fail, and so do they once the Playback
  # Session plays somewhere else, which `stop` tells the TV
  @impl true
  def handle_in(
        "heartbeat",
        %{"playback_id" => playback_id, "position_seconds" => position, "paused" => paused?},
        socket
      ) do
    %{session: session, cast: cast, user: user} = socket.assigns

    case Playbacks.heartbeat(session, cast.screen_id, playback_id, position, paused?, actor: user) do
      {:ok, session} ->
        {:noreply, assign(socket, :session, session)}

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} ->
        {:noreply, socket}
    end
  end

  def handle_in("ended", %{"playback_id" => playback_id}, socket) do
    %{session: session, cast: cast, user: user} = socket.assigns

    case Playbacks.play_next(session, cast.screen_id, playback_id, actor: user) do
      {:ok, _session} ->
        {:noreply, socket}

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} ->
        {:noreply, socket}
    end
  end

  # CAF's detailed error code, and its reason and Shaka Player's error code when it has them. A
  # critical one stopped the playback; CAF recovers from the others, and may report them again.
  def handle_in(
        "error",
        %{
          "code" => code,
          "reason" => reason,
          "shaka_code" => shaka_code,
          "critical" => critical?
        },
        socket
      ) do
    error =
      [code, reason, shaka_code && "Shaka #{shaka_code}"]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join(" ")

    if critical?,
      do:
        Logger.error("Cast — The TV failed to play: #{error}",
          event: :tv_playback_failed,
          error: error
        ),
      else:
        Logger.warning("Cast — The TV had a playback error: #{error}",
          event: :tv_playback_error,
          error: error
        )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:tv_command, command, position}, socket) do
    push(socket, "command", %{command: command, position_seconds: position})
    {:noreply, socket}
  end

  def handle_info(%Notification{resource: Session, action: action, data: session}, socket) do
    %{cast: cast, user: user} = socket.assigns

    cond do
      session.id != socket.assigns.session.id or action.name in [:heartbeat, :cast] ->
        {:noreply, socket}

      session.ended_at || session.screen_id != cast.screen_id ->
        push(socket, "stop", %{})
        {:stop, :normal, socket}

      true ->
        session = Ash.load!(session, NowPlaying.fields(), actor: user)
        push(socket, "state", state(session))
        {:noreply, assign(socket, :session, session)}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # The Playback Session has no Screen until the TV comes back. Fails when the TV stopped because
  # the Playback Session ended or plays somewhere else.
  @impl true
  def terminate(_reason, socket) do
    %{session: session, cast: cast, user: user} = socket.assigns

    case Playbacks.leave_screen(session, cast.screen_id, actor: user) do
      {:ok, _session} -> :telemetry.execute([:watch_club, :cast], %{count: 1}, %{result: :left})
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} -> :ok
    end
  end

  # What the TV plays. It finds the audio tracks by their order, which is the master playlist's,
  # and loads the subtitles from their files. While no Text Track Choice is picked, it shows the
  # Forced Text Track of the audio, if any.
  defp state(%Session{current_playback: %Playback{media: %{video: video}} = playback} = session) do
    choices = playback.text_track_choices
    forced = choices.forced[playback.audio_track_id]

    %{
      playback: %{
        id: playback.id,
        path: PlaybackPaths.master_playlist(playback),
        title: NowPlaying.title(video),
        subtitle: NowPlaying.subtitle(video),
        image: image_url(NowPlaying.still_path(video)),
        audio_track_ids: Enum.map(video.audio_tracks, & &1.id),
        text_tracks: NowPlaying.text_track_files(playback),
        audio_track_id: playback.audio_track_id,
        text_track_id: playback.text_track_id || (forced && forced.id)
      },
      position_seconds: session.position_seconds,
      paused: session.paused?
    }
  end

  defp image_url(nil), do: nil
  defp image_url(path), do: Url.content_image(path, "w1280")
end
