// The TV's side of casting. WatchClub's receiver page, in cast_receiver/, loads this file from
// the instance that casts. The TV joins the Playback Session over a socket, plays what it says
// through Google's receiver framework (CAF), follows the Remote's commands, and reports where
// it's at about every five seconds.
import { Socket } from "phoenix";

const { DetailedErrorCode, ErrorSeverity, EventType } = cast.framework.events;
const { PlayerState } = cast.framework.messages;

let stopCurrent;

// The CAF audio tracks in the order of the master playlist, which the TV finds ours by
const tracksInOrder = (manager) =>
	manager.getTracks().sort((a, b) => a.trackId - b.trackId);

// The master playlist lists no subtitles: they load from their files, under ids apart from the
// ones CAF gives its audio tracks
const textTrackId = (index) => 1000 + index;

const start = (context, { origin, token }) => {
	const playerManager = context.getPlayerManager();
	const socket = new Socket(`${origin.replace(/^http/, "ws")}/tv`, {
		params: { token },
	});
	const channel = socket.channel("tv", {});
	// The Playback asked for, and the one the TV reports about once it loaded
	let playback;
	let loadedPlaybackId;

	const load = ({ playback: next, position_seconds, paused }) => {
		playback = next;
		loadedPlaybackId = undefined;
		const media = new cast.framework.messages.MediaInformation();
		media.contentId = new URL(next.path, origin).href;
		media.contentUrl = media.contentId;
		media.contentType = "application/x-mpegurl";
		media.hlsSegmentFormat = cast.framework.messages.HlsSegmentFormat.TS;
		media.hlsVideoSegmentFormat =
			cast.framework.messages.HlsVideoSegmentFormat.MPEG2_TS;
		media.metadata = new cast.framework.messages.GenericMediaMetadata();
		media.metadata.title = next.title;
		media.metadata.subtitle = next.subtitle;
		media.metadata.images = next.image
			? [new cast.framework.messages.Image(next.image)]
			: [];
		media.tracks = next.text_tracks.map((track, index) => {
			const subtitles = new cast.framework.messages.Track(
				textTrackId(index),
				cast.framework.messages.TrackType.TEXT,
			);
			subtitles.trackContentId = new URL(track.path, origin).href;
			subtitles.trackContentType = "text/vtt";
			subtitles.subtype = cast.framework.messages.TextTrackType.SUBTITLES;
			subtitles.name = track.name;
			subtitles.language = track.language;
			return subtitles;
		});

		const request = new cast.framework.messages.LoadRequestData();
		request.media = media;
		request.currentTime = position_seconds;
		request.autoplay = !paused;
		playerManager.load(request).then(() => {
			// Unless another Playback started meanwhile
			if (playback.id === next.id) loadedPlaybackId = next.id;
		});
	};

	const applyTracks = () => {
		const audio = playerManager.getAudioTracksManager();
		const audioIndex = playback.audio_track_ids.indexOf(
			playback.audio_track_id,
		);
		const audioTrack = tracksInOrder(audio)[audioIndex];
		if (audioTrack && audio.getActiveId() !== audioTrack.trackId)
			audio.setActiveById(audioTrack.trackId);

		const textIndex = playback.text_tracks.findIndex(
			(track) => track.id === playback.text_track_id,
		);
		playerManager
			.getTextTracksManager()
			.setActiveByIds(textIndex === -1 ? [] : [textTrackId(textIndex)]);
	};

	// On joining, again after reconnecting, and whenever the Playback Session changes
	const play = (state) => {
		if (state.playback.id === playback?.id) {
			playback = state.playback;
			applyTracks();
		} else {
			load(state);
		}
	};

	const reportPosition = () => {
		if (!loadedPlaybackId) return;
		channel.push("heartbeat", {
			playback_id: loadedPlaybackId,
			position_seconds: playerManager.getCurrentTimeSec(),
			paused: playerManager.getPlayerState() === PlayerState.PAUSED,
		});
	};

	const listeners = [
		[EventType.PLAYER_LOAD_COMPLETE, applyTracks],
		[EventType.PLAY, reportPosition],
		[EventType.PAUSE, reportPosition],
		[EventType.SEEKED, reportPosition],
		// Only the TV sees them. Another load replacing this one, as when the next episode
		// starts, isn't one.
		[
			EventType.ERROR,
			(event) => {
				if (event.detailedErrorCode === DetailedErrorCode.LOAD_INTERRUPTED)
					return;
				channel.push("error", {
					code: event.detailedErrorCode ?? null,
					reason: event.reason ?? null,
					shaka_code: event.error?.shakaErrorCode ?? null,
					critical: event.severity === ErrorSeverity.CRITICAL,
				});
			},
		],
		[
			EventType.MEDIA_FINISHED,
			(event) => {
				if (loadedPlaybackId && event.endedReason === "END_OF_STREAM")
					channel.push("ended", { playback_id: loadedPlaybackId });
			},
		],
	];
	for (const [type, listener] of listeners)
		playerManager.addEventListener(type, listener);
	const heartbeatTimer = setInterval(reportPosition, 5000);

	channel.on("state", play);
	channel.on("command", ({ command, position_seconds }) => {
		if (command === "play") playerManager.play();
		if (command === "pause") playerManager.pause();
		if (command === "seek") playerManager.seek(position_seconds);
	});
	// Its Playback Session ended or plays somewhere else
	channel.on("stop", () => context.stop());
	channel
		.join()
		.receive("ok", play)
		.receive("error", () => context.stop());
	socket.connect();

	stopCurrent = () => {
		clearInterval(heartbeatTimer);
		for (const [type, listener] of listeners)
			playerManager.removeEventListener(type, listener);
		channel.leave();
		socket.disconnect();
	};
};

const stop = () => stopCurrent?.();

window.WatchClubTv = { start, stop };
