const defaultVidstackScriptUrl = "/assets/js/player_vidstack.js";
let vidstackLoadPromise;

const loadVidstack = (src = defaultVidstackScriptUrl) => {
	if (window.WatchClubVidstack?.Hls) return Promise.resolve(window.WatchClubVidstack);
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
				reject(new Error("Vidstack loaded without exposing window.WatchClubVidstack"));
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
const emptyStorageKeys = ["Volume", "Muted", "Time", "AudioGain", "PlaybackRate", "VideoQuality"];
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
		this.session = JSON.parse(this.el.dataset.session);
		this.vidstackScriptUrl = this.el.dataset.vidstackSrc || defaultVidstackScriptUrl;
		this.player = this.el.querySelector("[data-player-media]");
		this.captionsEl = this.el.querySelector("media-captions");
		this.abortController = new AbortController();
		this.disposed = false;
		this.stopped = false;
		this.playing = false;
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
		this.stopSession();
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

		window.addEventListener("pagehide", () => this.stopSession(), { signal });
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
			this.player.src = {
				src: this.session.master_url,
				type: "application/x-mpegurl",
			};
			this.player.startLoading?.();
		} catch (_error) {
			this.reportFailure();
		}
	},

	configurePlayer({ Hls }) {
		const signal = this.abortController.signal;

		this.player.title = this.session.title;
		this.player.duration = this.session.duration;
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
					remote.seek(clamp(player.currentTime - 10, 0, player.duration || this.session.duration), event);
				},
			},
			seekForward: {
				keys: "ArrowRight",
				onKeyDown: ({ event, player, remote }) => {
					event.preventDefault();
					this.reportHeartbeat();
					remote.seek(clamp(player.currentTime + 10, 0, player.duration || this.session.duration), event);
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

		this.player.addEventListener("can-play", () => this.reportReady(), { signal });
		this.player.addEventListener("playing", () => {
			this.playing = true;
			this.reportReady();
			this.reportHeartbeat();
			this.restartHeartbeatTimer();
		}, { signal });
		this.player.addEventListener("play", () => this.reportHeartbeat(), { signal });
		this.player.addEventListener("pause", () => {
			this.playing = false;
			this.reportHeartbeat();
		}, { signal });
		this.player.addEventListener("ended", () => {
			this.playing = false;
			this.reportHeartbeat();
		}, { signal });
		this.player.addEventListener("seeked", () => this.reportHeartbeat(), { signal });
		this.player.addEventListener("play-fail", () => this.reportFailure(), { signal });
		this.player.addEventListener("hls-unsupported", () => this.reportFailure(), { signal });
		this.player.addEventListener(
			"hls-error",
			(event) => {
				if (event.detail?.fatal) this.reportFailure();
			},
			{ signal },
		);
		this.player.addEventListener("error", () => this.reportFailure(), { signal });
		this.player.addEventListener("text-track-change", (event) => this.syncCaptionLayer(event.detail), {
			signal,
		});
		this.player.addEventListener("hls-cues-parsed", () => this.syncCaptionLayer(), { signal });
		this.player.addEventListener("volume-change", () => {
			this.storeLocalPreferences();
			this.reportHeartbeat();
		}, { signal });

		this.el
			.querySelectorAll("media-quality-radio-group, media-audio-radio-group, media-captions-radio-group")
			.forEach((group) => {
				group.addEventListener(
					"change",
					(event) => {
						if (event.currentTarget.localName === "media-captions-radio-group") {
							this.syncCaptionLayer(event.detail);
						}

						event.target.closest("media-menu")?.close?.(event);
					},
					{ signal },
				);
			});

	},

	restoreLocalPreferences() {
		const storedVolume = window.localStorage.getItem("watch-club:player-volume");
		const storedMuted = window.localStorage.getItem("watch-club:player-muted");

		if (storedVolume !== null && storedVolume !== "0") {
			const volume = Number(storedVolume);
			if (Number.isFinite(volume) && volume > 0) this.player.volume = clamp(volume, 0, 1);
		}

		this.player.muted = storedMuted === "true";
	},

	storeLocalPreferences() {
		window.localStorage.setItem("watch-club:player-volume", String(this.player.volume));
		window.localStorage.setItem("watch-club:player-muted", String(this.player.muted));
	},

	syncCaptionLayer(selectedTrack = this.player.textTracks?.selected ?? null, provider = this.player.provider) {
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
		if (Array.isArray(source)) return source.some((item) => item?.type?.includes("mpegurl"));
		return source?.type?.includes("mpegurl") || source?.src?.includes?.(".m3u8");
	},

	disableNativeTextTracks(video = this.getVideoElement()) {
		Array.from(video?.textTracks || []).forEach((track) => {
			track.mode = "disabled";
		});
	},

	restartHeartbeatTimer() {
		if (this.heartbeatTimer) window.clearInterval(this.heartbeatTimer);

		this.heartbeatTimer = window.setInterval(() => {
			if (!this.disposed && !this.stopped && this.playing) {
				this.reportHeartbeat();
			}
		}, 5000);
	},

	reportReady() {
		this.pushEvent("player_ready", {}, () => {});
	},

	reportHeartbeat() {
		this.pushEvent("player_heartbeat", {}, () => {});
	},

	reportFailure() {
		this.pushEvent("player_failed", {}, () => {});
	},

	stopSession() {
		if (this.stopped) return;
		this.stopped = true;
		this.playing = false;
		this.pushEvent("player_stop", {}, () => {});
	},
};

export default { Player };
