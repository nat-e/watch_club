const defaultVidstackScriptUrl = "/assets/js/player_vidstack.js";
let vidstackLoadPromise;

const loadVidstack = (src = defaultVidstackScriptUrl) => {
	if (window.WatchClubVidstack?.Hls)
		return Promise.resolve(window.WatchClubVidstack);
	if (vidstackLoadPromise) return vidstackLoadPromise;

	vidstackLoadPromise = new Promise((resolve, reject) => {
		const script = document.createElement("script");
		script.async = true;
		script.src = src;
		script.onload = () => {
			if (window.WatchClubVidstack?.Hls) {
				resolve(window.WatchClubVidstack);
			} else {
				vidstackLoadPromise = undefined;
				reject(
					new Error(
						"Vidstack loaded without exposing window.WatchClubVidstack",
					),
				);
			}
		};
		script.onerror = () => {
			vidstackLoadPromise = undefined;
			reject(new Error("Could not load Vidstack"));
		};
		document.head.append(script);
	});

	return vidstackLoadPromise;
};

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
const getNothing = async () => null;
const noop = async () => {};
const emptyStorageKeys = [
	"Volume",
	"Muted",
	"Time",
	"AudioGain",
	"PlaybackRate",
	"VideoQuality",
];
const emptyPlayerStorage = Object.fromEntries(
	emptyStorageKeys.flatMap((key) => [
		[`get${key}`, getNothing],
		[`set${key}`, noop],
	]),
);

const createPlayerStorage = () => {
	let captions = false;
	let language = null;

	return {
		...emptyPlayerStorage,
		getCaptions: async () => captions,
		setCaptions: async (enabled) => {
			captions = enabled;
		},
		getLang: async () => language,
		setLang: async (lang) => {
			language = lang;
		},
	};
};

const Player = {
	mounted() {
		this.handleEvent("player:load_video", ({ src }) => this.loadVideo(src));
		this.vidstackScriptUrl =
			this.el.dataset.vidstackSrc || defaultVidstackScriptUrl;
		this.player = this.el.querySelector("[data-player-media]");
		this.captionsEl = this.el.querySelector("media-captions");
		this.abortController = new AbortController();
		this.disposed = false;
		this.heartbeatTimer = undefined;

		this.bindDomEvents();
		this.boot();
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
	},

	// This is called on initial load and when the video changes in the player session
	// Playback starts at the given position (the beginning by default) but keeps
	// track selection intact. Vidstack queues the seek until the media can play.
	loadVideo(src, startPositionSeconds = 0) {
		if (!this.player) return;
		this.pendingAutoplay = true;
		this.player.src = { src, type: "application/x-mpegurl" };
		this.player.currentTime = startPositionSeconds;
		this.player.startLoading?.();
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
			const vidstack = await loadVidstack(this.vidstackScriptUrl);
			if (this.disposed) return;

			this.configurePlayer(vidstack);
			this.loadVideo(
				this.player.dataset.src,
				Number(this.player.dataset.startPosition) || 0,
			);
		} catch (_error) {
			this.reportFailure();
		}
	},

	configurePlayer({ Hls }) {
		const signal = this.abortController.signal;

		this.player.preload = "metadata";
		this.player.playsInline = true;
		this.player.preferNativeHLS = false;
		this.player.storage = createPlayerStorage();
		this.player.keyTarget = "document";
		this.player.keyShortcuts = {
			togglePaused: "k Space",
			toggleMuted: "m",
			toggleFullscreen: "f",
			seekBackward: {
				keys: "ArrowLeft",
				onKeyDown: ({ event, player, remote }) => {
					event.preventDefault();
					this.reportHeartbeat();
					remote.seek(
						clamp(player.currentTime - 10, 0, player.duration),
						event,
					);
				},
			},
			seekForward: {
				keys: "ArrowRight",
				onKeyDown: ({ event, player, remote }) => {
					event.preventDefault();
					this.reportHeartbeat();
					remote.seek(
						clamp(player.currentTime + 10, 0, player.duration),
						event,
					);
				},
			},
		};

		if (this.player.qualities) this.player.qualities.switch = "current";

		this.restoreLocalPreferences();

		this.player.addEventListener(
			"provider-change",
			(event) => {
				const provider = event.detail;
				this.syncCaptionLayer(undefined, provider);

				if (provider?.type !== "hls") return;

				provider.library = Hls;
				provider.config = {
					enableWorker: true,
					lowLatencyMode: false,
					renderTextTracksNatively: false,
					backBufferLength: 120,
					maxBufferLength: 36,
					maxMaxBufferLength: 90,
				};
			},
			{ signal },
		);

		this.player.addEventListener(
			"can-play",
			() => {
				this.reportReady();

				if (this.pendingAutoplay) {
					this.pendingAutoplay = false;
					// Rejected when the browser blocks autoplay; the user can press play.
					this.player.play().catch(() => {});
				}
			},
			{ signal },
		);
		this.player.addEventListener(
			"playing",
			() => {
				this.reportReady();
				this.reportHeartbeat();
				this.restartHeartbeatTimer();
			},
			{ signal },
		);
		this.player.addEventListener("play", () => this.reportHeartbeat(), {
			signal,
		});
		this.player.addEventListener("pause", () => this.reportHeartbeat(), {
			signal,
		});
		this.player.addEventListener(
			"ended",
			() => {
				this.reportHeartbeat();
				// Auto-advance once the episode ends. The server no-ops when there is no
				// next episode
				this.pushEvent("play_next_episode", {});
			},
			{ signal },
		);
		// Reveal the auto-advance "up next" overlay during the last 5 seconds. CSS keys
		// off [data-near-end] on the player root to fade it in and run the fill animation.
		this.player.addEventListener(
			"time-update",
			() => {
				const { currentTime, duration } = this.player;
				const nearEnd =
					Number.isFinite(duration) &&
					duration > 0 &&
					duration - currentTime <= 5;
				this.player.toggleAttribute("data-near-end", nearEnd);
			},
			{ signal },
		);
		this.player.addEventListener("seeked", () => this.reportHeartbeat(), {
			signal,
		});
		this.player.addEventListener("play-fail", () => this.reportFailure(), {
			signal,
		});
		this.player.addEventListener(
			"hls-unsupported",
			() => this.reportFailure(),
			{ signal },
		);
		this.player.addEventListener(
			"hls-error",
			(event) => {
				if (event.detail?.fatal) this.reportFailure();
			},
			{ signal },
		);
		this.player.addEventListener("error", () => this.reportFailure(), {
			signal,
		});
		this.player.addEventListener(
			"text-track-change",
			(event) => this.syncCaptionLayer(event.detail),
			{
				signal,
			},
		);
		this.player.addEventListener(
			"hls-cues-parsed",
			() => this.syncCaptionLayer(),
			{ signal },
		);
		this.player.addEventListener(
			"volume-change",
			() => {
				this.storeLocalPreferences();
				this.reportHeartbeat();
			},
			{ signal },
		);

		this.el
			.querySelectorAll(
				"media-quality-radio-group, media-audio-radio-group, media-captions-radio-group",
			)
			.forEach((group) => {
				group.addEventListener(
					"change",
					(event) => {
						if (
							event.currentTarget.localName === "media-captions-radio-group"
						) {
							this.syncCaptionLayer(event.detail);
						}

						// Return focus to the trigger before closing, otherwise the menu is
						// hidden (aria-hidden) while the just-clicked radio still holds focus.
						const menu = event.currentTarget.closest("media-menu");
						menu?.querySelector("media-menu-button")?.focus();
						menu?.close?.(event);
					},
					{ signal },
				);
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
				this.player.volume = clamp(volume, 0, 1);
		}

		this.player.muted = storedMuted === "true";
	},

	storeLocalPreferences() {
		window.localStorage.setItem(
			"watch-club:player-volume",
			String(this.player.volume),
		);
		window.localStorage.setItem(
			"watch-club:player-muted",
			String(this.player.muted),
		);
	},

	syncCaptionLayer(
		selectedTrack = this.player.textTracks?.selected ?? null,
		provider = this.player.provider,
	) {
		const providerType = provider?.type;
		const usingNativeHls = providerType === "video" && this.isHlsSource();

		if (this.captionsEl) {
			this.captionsEl.hidden = usingNativeHls || !selectedTrack;
			if (!selectedTrack) this.captionsEl.replaceChildren();
		}

		if (providerType === "hls") this.disableNativeTextTracks();
	},

	getVideoElement() {
		return this.player.provider?.video || this.player.querySelector("video");
	},

	isHlsSource() {
		const source = this.player.src;
		if (typeof source === "string") return source.includes(".m3u8");
		if (Array.isArray(source))
			return source.some((item) => item?.type?.includes("mpegurl"));
		return (
			source?.type?.includes("mpegurl") || source?.src?.includes?.(".m3u8")
		);
	},

	disableNativeTextTracks(video = this.getVideoElement()) {
		Array.from(video?.textTracks || []).forEach((track) => {
			track.mode = "disabled";
		});
	},

	// Keeps running while paused, so the Playback stays current as long as the
	// Player is open.
	restartHeartbeatTimer() {
		if (this.heartbeatTimer) window.clearInterval(this.heartbeatTimer);

		this.heartbeatTimer = window.setInterval(() => this.reportHeartbeat(), 5000);
	},

	reportReady() {
		this.pushEvent("player_ready", {}, () => {});
	},

	reportHeartbeat() {
		const position = this.player?.currentTime;
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
