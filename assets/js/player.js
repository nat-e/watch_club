let videojsLoadPromise;

// Loads the Video.js elements, which register themselves
const loadVideojs = (src) => {
	videojsLoadPromise ??= new Promise((resolve, reject) => {
		const script = document.createElement("script");
		script.async = true;
		script.src = src;
		script.onload = resolve;
		script.onerror = () => {
			videojsLoadPromise = undefined;
			script.remove();
			reject(new Error("Could not load Video.js"));
		};
		document.head.append(script);
	});

	return videojsLoadPromise;
};

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

// Limits how far ahead hls.js buffers, because the server transcodes segments on demand
const hlsConfig = {
	backBufferLength: 120,
	maxBufferLength: 36,
	maxMaxBufferLength: 90,
};

const Player = {
	mounted() {
		this.media = this.el.querySelector("hlsjs-video");
		this.abortController = new AbortController();
		this.disposed = false;
		this.heartbeatTimer = undefined;
		// The audio language to carry over to the next video
		this.carriedAudio = undefined;
		// The subtitles to carry over to the next video, as hls.js's language and forced
		// flag: null for none, undefined for the ones the master playlist marks as default
		this.carriedSubtitles = undefined;

		this.bindDomEvents();
		this.boot();
	},

	// The server renders the next video of the session in the data attributes
	updated() {
		if (this.ready && this.el.dataset.src !== this.src) this.loadVideo();
	},

	destroyed() {
		this.cleanup();
	},

	cleanup() {
		if (this.disposed) return;
		this.disposed = true;
		this.abortController.abort();
		if (this.heartbeatTimer) window.clearInterval(this.heartbeatTimer);
	},

	bindDomEvents() {
		const signal = this.abortController.signal;

		this.el.querySelectorAll("[data-player-command]").forEach((button) => {
			button.addEventListener(
				"click",
				(event) => {
					event.preventDefault();
					event.stopPropagation();
					this.handleCommand(button.dataset.playerCommand);
				},
				{ signal },
			);
		});

		// From the top bar, the Settings menu and the error screen
		this.el.addEventListener(
			"player:report-problem",
			() => this.reportProblem(),
			{ signal },
		);

		// Delegated: the skip buttons change with each episode
		this.el.addEventListener(
			"click",
			(event) => {
				const skipButton = event.target.closest("[data-skip-to]");
				if (skipButton)
					this.media.currentTime = Number(skipButton.dataset.skipTo);
			},
			{ signal },
		);
	},

	handleCommand(command) {
		switch (command) {
			case "back":
				if (window.history.length > 1) window.history.back();
				else window.location.assign("/");
				break;
		}
	},

	async boot() {
		try {
			await loadVideojs(this.el.dataset.videojsSrc);
			if (this.disposed) return;

			this.bindMediaEvents();
			this.restoreLocalPreferences();
			this.ready = true;
			this.loadVideo();
		} catch (_error) {
			this.reportFailure();
		}
	},

	// Loads the video in the data attributes, which plays on its own from their start
	// position, with the audio and subtitles of the previous video when it has them
	loadVideo() {
		const { src, thumbnailsSrc, startPosition } = this.el.dataset;
		this.carryTracksOver();
		this.tracksStarted = false;
		// Where the countdown of the "up next" prompt started, in seconds of the video
		this.countdownStart = undefined;
		this.playingNext = false;
		this.src = src;
		this.startPosition = Number(startPosition);
		// A new audio preference makes Video.js build a new hls.js engine
		this.media.source = {
			src,
			engine: {
				hlsJs: {
					...hlsConfig,
					audioPreference: this.carriedAudio && { lang: this.carriedAudio },
				},
			},
		};

		const thumbnails = document.createElement("track");
		thumbnails.kind = "metadata";
		thumbnails.label = "thumbnails";
		thumbnails.default = true;
		thumbnails.src = thumbnailsSrc;
		this.media.querySelector("track")?.remove();
		this.media.append(thumbnails);
	},

	bindMediaEvents() {
		const signal = this.abortController.signal;
		const on = (type, listener) =>
			this.media.addEventListener(type, listener, { signal });

		on("loadedmetadata", () => {
			// Seeking now, rather than starting hls.js at the position, loads the first
			// segment, which hls.js needs to place the subtitles
			if (this.startPosition) this.media.currentTime = this.startPosition;
			// The browser has picked subtitles on its own by now
			this.startSubtitles();
			this.tracksStarted = true;
		});
		on("canplay", () => this.reportReady());
		on("playing", () => {
			this.reportReady();
			this.reportHeartbeat();
			this.restartHeartbeatTimer();
		});
		on("play", () => this.reportHeartbeat());
		on("pause", () => this.reportHeartbeat());
		// The countdown counts playback: a seek starts it again
		on("seeking", () => {
			this.countdownStart = undefined;
		});
		on("seeked", () => this.reportHeartbeat());
		on("ended", () => {
			this.reportHeartbeat();
			const upNext = this.el.querySelector("[data-countdown]");
			if (upNext) this.playNext(upNext);
		});
		on("timeupdate", () => this.syncPrompts());
		// Includes fatal hls.js errors
		on("error", () => this.reportFailure());
		on("volumechange", () => {
			this.storeLocalPreferences();
			this.reportHeartbeat();
		});
	},

	restoreLocalPreferences() {
		const storedVolume = window.localStorage.getItem(
			"watch-club:player-volume",
		);
		const storedMuted = window.localStorage.getItem("watch-club:player-muted");

		if (storedVolume !== null && storedVolume !== "0") {
			const volume = Number(storedVolume);
			if (Number.isFinite(volume) && volume > 0)
				this.media.volume = clamp(volume, 0, 1);
		}

		this.media.muted = storedMuted === "true";
	},

	storeLocalPreferences() {
		window.localStorage.setItem(
			"watch-club:player-volume",
			String(this.media.volume),
		);
		window.localStorage.setItem(
			"watch-club:player-muted",
			String(this.media.muted),
		);
	},

	// The next video of the session starts with the audio language and the subtitles
	// playing now, when it has them
	carryTracksOver() {
		const hls = this.media.engine;
		// Until this video starts its tracks, the previous video's still carry over
		if (!hls || !this.tracksStarted) return;

		this.carriedAudio = hls.audioTracks[hls.audioTrack]?.lang;
		// Forced and full subtitles can share a language
		const subtitles = this.showingSubtitles(hls.subtitleTracks);
		this.carriedSubtitles = subtitles
			? { lang: subtitles.lang, forced: subtitles.forced }
			: null;
	},

	// Starts the subtitles carried over from the previous video when this one has them,
	// otherwise the ones the master playlist marks as default
	startSubtitles() {
		const hls = this.media.engine;
		if (!hls) return;

		const carried = this.carriedSubtitles;
		const subtitles =
			carried === null
				? undefined
				: (hls.subtitleTracks.find(
						(track) =>
							track.lang === carried?.lang && track.forced === carried?.forced,
					) ?? hls.subtitleTracks.find((track) => track.default));

		for (const textTrack of this.subtitleTextTracks()) {
			textTrack.mode = this.isTextTrackOf(textTrack, subtitles)
				? "showing"
				: "disabled";
		}
	},

	// hls.js keeps its subtitle track when they're turned off, so the showing text track
	// tells which ones play
	showingSubtitles(subtitleTracks) {
		const showing = this.subtitleTextTracks().find(
			(textTrack) => textTrack.mode === "showing",
		);
		return subtitleTracks.find((track) => this.isTextTrackOf(showing, track));
	},

	subtitleTextTracks() {
		return Array.from(this.media.textTracks).filter(
			(textTrack) =>
				textTrack.kind === "subtitles" || textTrack.kind === "captions",
		);
	},

	// Video.js gives each hls.js subtitle track a text track with its name and language
	isTextTrackOf(textTrack, subtitles) {
		return (
			textTrack !== undefined &&
			subtitles !== undefined &&
			textTrack.label === subtitles.name &&
			textTrack.language === subtitles.lang
		);
	},

	// Reveals each prompt, such as "Skip intro", from its data-show-from until its
	// data-show-until, in seconds of the video. The one with data-countdown fills up over
	// 5 seconds of playback, so pausing pauses it, then plays the next episode.
	syncPrompts() {
		const { currentTime } = this.media;

		this.el.querySelectorAll("[data-show-from]").forEach((prompt) => {
			// A seek lands within a few microseconds of its target, such as the end
			// of an Intro
			const active =
				currentTime > 0 &&
				currentTime >= Number(prompt.dataset.showFrom) &&
				!(currentTime >= Number(prompt.dataset.showUntil) - 0.01);
			prompt.toggleAttribute("data-active", active);

			if (!("countdown" in prompt.dataset)) return;
			if (!active) {
				this.countdownStart = undefined;
				prompt.style.removeProperty("--countdown");
				return;
			}
			this.countdownStart ??= currentTime;
			const progress = Math.min((currentTime - this.countdownStart) / 5, 1);
			prompt.style.setProperty("--countdown", String(progress));
			if (progress === 1) this.playNext(prompt);
		});
	},

	// Clicks the "up next" prompt once: the next episode replaces it
	playNext(upNext) {
		if (this.playingNext) return;
		this.playingNext = true;
		upNext.click();
	},

	// Pauses the video, then opens Report a Problem with what the Player shows. Before
	// its metadata loads, the video has no time or tracks to show.
	reportProblem() {
		if (!this.tracksStarted) {
			this.pushEvent("report_problem", {});
			return;
		}

		this.media.pause();
		const store = this.el.querySelector("video-player").store;
		const audio = store.audioTrackList.find((track) => track.enabled);
		const subtitles = store.textTrackList.find(
			(track) =>
				track.mode === "showing" &&
				(track.kind === "subtitles" || track.kind === "captions"),
		);
		const rendition = store.activeVideoRendition;
		// Auto quality selects no rendition
		const auto = !store.videoRenditionList.some((option) => option.selected);

		this.pushEvent("report_problem", {
			position_seconds: store.currentTime,
			audio: audio?.label,
			subtitles: subtitles?.label,
			quality:
				rendition?.height && `${auto ? "Auto, " : ""}${rendition.height}p`,
		});
	},

	// Keeps running while paused, so the Playback stays current as long as the
	// Player is open.
	restartHeartbeatTimer() {
		if (this.heartbeatTimer) window.clearInterval(this.heartbeatTimer);

		this.heartbeatTimer = window.setInterval(
			() => this.reportHeartbeat(),
			5000,
		);
	},

	reportReady() {
		this.pushEvent("player_ready", {}, () => {});
	},

	reportHeartbeat() {
		const position = this.media.currentTime;
		this.pushEvent(
			"player_heartbeat",
			{ position_seconds: Number.isFinite(position) ? position : null },
			() => {},
		);
	},

	reportFailure() {
		this.pushEvent("player_failed", {}, () => {});
	},
};

export default { Player };
