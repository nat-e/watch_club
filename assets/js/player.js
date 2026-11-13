import { castContext, startCasting } from "./cast_sender";

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
		// The tracks the server knows this video plays, as `tracks_picked` sends them
		this.reportedTracks = undefined;

		this.handleEvent("player:back", () => this.handleCommand("back"));
		this.bindDomEvents();
		this.boot();
		this.offerCasting();
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
		this.casting?.dispose();
	},

	bindDomEvents() {
		// From the top bar, the Settings menu and the error screen
		this.el.addEventListener(
			"player:report-problem",
			() => this.reportProblem(),
			{ signal: this.abortController.signal },
		);

		this.el.addEventListener(
			"value-change",
			(event) => {
				if (event.target.matches("[data-subtitles-menu]"))
					this.pickSubtitles(event.detail.value);
			},
			{ signal: this.abortController.signal },
		);

		// Delegated: the skip buttons change with each episode, and the server renders the
		// casting overlay
		this.el.addEventListener(
			"click",
			(event) => {
				const skipButton = event.target.closest("[data-skip-to]");
				if (skipButton)
					this.media.currentTime = Number(skipButton.dataset.skipTo);

				const commandButton = event.target.closest("[data-player-command]");
				if (commandButton) {
					event.preventDefault();
					event.stopPropagation();
					this.handleCommand(commandButton.dataset.playerCommand);
				}
			},
			{ signal: this.abortController.signal },
		);
	},

	handleCommand(command) {
		switch (command) {
			case "back":
				if (window.history.length > 1) window.history.back();
				else window.location.assign("/");
				break;
			case "cast":
				this.cast();
				break;
			case "cancel-cast":
				this.casting?.cancel();
				this.stopHandingOver("cancelled");
				break;
		}
	},

	// Shows the cast button wherever Chrome can cast, TV or not: on a computer, Chrome only looks
	// for TVs once its Cast dialog opens
	async offerCasting() {
		const { castAppId, castEmulator } = this.el.dataset;
		if (await castContext(castAppId, castEmulator))
			this.el.querySelector("#player-cast-button").hidden = false;
	},

	// Once Chrome connected to the TV, the TV takes the Playback Session from where this
	// Player paused it, and the server opens the Remote
	async cast() {
		const { castAppId, castEmulator } = this.el.dataset;
		this.casting = await startCasting(castAppId, castEmulator, {
			// The TV goes on playing, or stays paused, from here
			beforeLaunch: () => {
				this.reportHeartbeat();
				this.handingOver = true;
				this.media.pause();
			},
			token: (tvName) =>
				new Promise((resolve) =>
					this.pushEvent("cast", { tv_name: tvName }, ({ token }) =>
						resolve(token),
					),
				),
			onFailure: () => this.stopHandingOver("timeout"),
		});
	},

	// `timeout` when the TV never took over, `cancelled` when the User gave up, whichever comes
	// first
	stopHandingOver(reason) {
		if (!this.handingOver) return;
		this.handingOver = false;
		this.pushEvent("cast_failed", { reason });
	},

	async boot() {
		try {
			await loadVideojs(this.el.dataset.videojsSrc);
			if (this.disposed) return;

			this.bindMediaEvents();
			this.restoreLocalPreferences();
			this.ready = true;
			this.loadVideo();
			// The Player is a Screen of the Playback Session as long as it's open
			this.heartbeatTimer = window.setInterval(
				() => this.reportHeartbeat(),
				5000,
			);
		} catch (_error) {
			this.reportFailure();
		}
	},

	// Loads the video in the data attributes, which plays on its own from their start
	// position, with the audio the master playlist marks as default and the subtitles picked.
	// The master playlist lists no subtitles: each Text Track loads from its file, under its id.
	loadVideo() {
		const { src, thumbnailsSrc, startPosition } = this.el.dataset;
		this.loadSubtitlesMenus();
		this.reportedTracks = undefined;
		// Where the countdown of the "up next" prompt started, in seconds of the video
		this.countdownStart = undefined;
		this.playingNext = false;
		this.src = src;
		this.media.source = {
			src,
			engine: { hlsJs: { ...hlsConfig, startPosition: Number(startPosition) } },
		};

		for (const track of this.media.querySelectorAll("track")) track.remove();

		const thumbnails = document.createElement("track");
		thumbnails.kind = "metadata";
		thumbnails.label = "thumbnails";
		thumbnails.default = true;
		thumbnails.src = thumbnailsSrc;
		this.media.append(thumbnails);

		const { tracks } = JSON.parse(this.el.dataset.subtitles);
		for (const { id, path, name, language } of tracks) {
			const subtitles = document.createElement("track");
			subtitles.kind = "subtitles";
			subtitles.id = id;
			subtitles.src = path;
			subtitles.label = name;
			subtitles.srclang = language ?? "";
			this.media.append(subtitles);
		}
	},

	bindMediaEvents() {
		const signal = this.abortController.signal;
		const on = (type, listener) =>
			this.media.addEventListener(type, listener, { signal });

		on("loadedmetadata", () => {
			// The browser has picked subtitles on its own by now
			this.showSubtitles();

			// Off shows the Forced Text Track of the audio. Each video has its own audio tracks.
			this.audioTracksListener?.abort();
			this.audioTracksListener = new AbortController();
			this.media.audioTracks?.addEventListener(
				"change",
				() => this.showSubtitles(),
				{ signal: this.audioTracksListener.signal },
			);
		});

		on("canplay", () => this.reportReady());
		on("playing", () => {
			this.reportReady();
			this.reportHeartbeat();
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
			else this.pushEvent("ended", { playback_id: this.el.dataset.playbackId });
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

	// The subtitles menus offer the server's Text Track Choices, from their <template>, and Off.
	// In the top bar and in Settings.
	loadSubtitlesMenus() {
		const { choices, picked } = JSON.parse(this.el.dataset.subtitles);
		for (const menu of this.el.querySelectorAll("[data-subtitles-menu]")) {
			for (const item of menu.querySelectorAll("[data-choice]")) item.remove();
			const template = menu.querySelector("template").content;
			for (const { id, name } of choices) {
				const item = template.firstElementChild.cloneNode(true);
				item.setAttribute("value", id);
				item.dataset.choice = "";
				item.querySelector('[data-part="label"]').textContent = name;
				menu.append(item);
			}
		}
		this.pickSubtitles(picked);
	},

	// `off`, or the id of a Text Track Choice
	pickSubtitles(value) {
		const { choices } = JSON.parse(this.el.dataset.subtitles);
		this.pickedSubtitles = value;
		for (const menu of this.el.querySelectorAll("[data-subtitles-menu]")) {
			menu.value = value;
			// As Video.js's own groups do: shows the menu, and in Settings what's picked
			menu.publishMenuOptionState(
				false,
				choices.length === 0,
				choices.length === 0 ? "unavailable" : "available",
			);
		}
		this.showSubtitles();
	},

	// Shows the subtitles picked, or with Off, the Forced Text Track of the audio, if any
	showSubtitles() {
		const { forced } = JSON.parse(this.el.dataset.subtitles);
		const id =
			this.pickedSubtitles === "off"
				? forced[this.playingTracks().audio_track_id]
				: this.pickedSubtitles;
		for (const textTrack of this.subtitleTextTracks())
			textTrack.mode = textTrack.id === id ? "showing" : "disabled";
	},

	// The ids of the tracks playing: the audio from its playlist's path, else the Playback's, until
	// hls.js tells which plays. Native HLS doesn't.
	playingTracks() {
		const hls = this.media.engine;
		const audio = hls?.audioTracks[hls.audioTrack];

		return {
			audio_track_id:
				audio?.url.match(/\/audio\/([^/]+)\//)?.[1] ??
				this.el.dataset.audioTrackId ??
				null,
			text_track_id:
				this.pickedSubtitles === "off" ? null : this.pickedSubtitles,
		};
	},

	subtitleTextTracks() {
		return Array.from(this.media.textTracks).filter(
			(textTrack) =>
				textTrack.kind === "subtitles" || textTrack.kind === "captions",
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

	// Pauses the video, then opens Report a Problem with what the Player shows: the time,
	// and the audio, subtitles and quality its menus show. Before its metadata loads, the
	// video has no time or tracks to show.
	reportProblem() {
		// Unless Video.js failed to load
		if (this.ready) this.media.pause();
		if (!this.ready || this.media.readyState === 0) {
			this.pushEvent("report_problem", {});
			return;
		}

		const store = this.el.querySelector("video-player").store;
		const picked = (menuId) =>
			this.el
				.querySelector(
					`#${menuId} media-menu-radio-item[aria-checked="true"] [data-part="label"]`,
				)
				?.textContent.trim();

		this.pushEvent("report_problem", {
			position_seconds: store.currentTime,
			audio: picked("player-audio-menu"),
			subtitles:
				this.pickedSubtitles === "off"
					? undefined
					: picked("player-subtitles-menu"),
			quality: picked("player-quality-menu"),
		});
	},

	reportReady() {
		this.pushEvent("player_ready", {}, () => {});
	},

	// Also tells the server the tracks the User picked, once they're playing. Stops while the
	// TV takes over.
	reportHeartbeat() {
		if (this.handingOver) return;

		const position = this.media.currentTime;
		const playbackId = this.el.dataset.playbackId;
		this.pushEvent(
			"player_heartbeat",
			{
				playback_id: playbackId,
				position_seconds: Number.isFinite(position) ? position : 0,
				paused: this.media.paused,
			},
			() => {},
		);

		if (this.media.readyState === 0) return;
		const tracks = this.playingTracks();
		const reported = JSON.stringify(tracks);
		if (this.reportedTracks === undefined) {
			this.reportedTracks = reported;
		} else if (reported !== this.reportedTracks) {
			this.reportedTracks = reported;
			this.pushEvent(
				"tracks_picked",
				{ playback_id: playbackId, ...tracks },
				() => {},
			);
		}
	},

	reportFailure() {
		this.pushEvent("player_failed", {}, () => {});
	},
};

export default { Player };
