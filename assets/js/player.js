const defaultHlsScriptUrl = "/assets/js/player_hls.js";
let hlsLoadPromise;

const loadHls = (src = defaultHlsScriptUrl) => {
	if (window.Hls) return Promise.resolve(window.Hls);
	if (hlsLoadPromise) return hlsLoadPromise;

	hlsLoadPromise = new Promise((resolve, reject) => {
		const script = document.createElement("script");
		script.async = true;
		script.src = src;
		script.onload = () => {
			if (window.Hls) {
				resolve(window.Hls);
			} else {
				hlsLoadPromise = undefined;
				reject(new Error("hls.js loaded without exposing window.Hls"));
			}
		};
		script.onerror = () => {
			hlsLoadPromise = undefined;
			reject(new Error("Could not load hls.js"));
		};
		document.head.append(script);
	});

	return hlsLoadPromise;
};

const formatTime = (value) => {
	if (!Number.isFinite(value)) return "0:00";

	const total = Math.max(0, Math.floor(value));
	const minutes = Math.floor(total / 60);
	const seconds = String(total % 60).padStart(2, "0");

	return `${minutes}:${seconds}`;
};

const statusClass = (kind) =>
	kind === "error"
		? "rounded-full border border-danger-border bg-danger-bg px-related py-tight text-sm font-medium text-danger"
		: "rounded-full border border-info-border bg-info-bg px-related py-tight text-sm font-medium text-info";

const Player = {
	mounted() {
		this.session = JSON.parse(this.el.dataset.session);
		this.hlsScriptUrl = this.el.dataset.hlsSrc;
		this.video = this.el.querySelector("[data-player-video]");
		this.qualitySelect = this.el.querySelector("[data-player-quality]");
		this.audioSelect = this.el.querySelector("[data-player-audio]");
		this.subtitleSelect = this.el.querySelector("[data-player-subtitles]");
		this.statusEl = this.el.querySelector("[data-player-status]");
		this.cacheEl = this.el.querySelector("[data-player-cache]");
		this.positionEl = this.el.querySelector("[data-player-position]");
		this.stopped = false;
		this.disposed = false;

		this.seekBackHandler = () => {
			this.video.currentTime = Math.max(0, this.video.currentTime - 10);
		};
		this.seekForwardHandler = () => {
			this.video.currentTime = Math.min(
				this.video.duration || this.session.duration,
				this.video.currentTime + 10,
			);
		};
		this.timeUpdateHandler = () => {
			this.positionEl.textContent = `${formatTime(this.video.currentTime)} / ${formatTime(this.video.duration || this.session.duration)}`;
		};
		this.pageHideHandler = () => this.stopSession();

		this.el
			.querySelector("[data-player-seek-back]")
			.addEventListener("click", this.seekBackHandler);
		this.el
			.querySelector("[data-player-seek-forward]")
			.addEventListener("click", this.seekForwardHandler);
		this.video.addEventListener("timeupdate", this.timeUpdateHandler);
		window.addEventListener("pagehide", this.pageHideHandler);

		this.boot();
		this.statusTimer = window.setInterval(() => this.refreshStatus(), 3000);
		this.refreshStatus();
	},

	destroyed() {
		this.cleanup();
	},

	cleanup() {
		this.disposed = true;
		window.clearInterval(this.statusTimer);
		window.removeEventListener("pagehide", this.pageHideHandler);
		this.video.removeEventListener("timeupdate", this.timeUpdateHandler);
		this.el
			.querySelector("[data-player-seek-back]")
			.removeEventListener("click", this.seekBackHandler);
		this.el
			.querySelector("[data-player-seek-forward]")
			.removeEventListener("click", this.seekForwardHandler);

		if (this.hls) this.hls.destroy();
		this.stopSession();
	},

	setStatus(message, kind = "info") {
		this.statusEl.textContent = message;
		this.statusEl.className = statusClass(kind);
	},

	refreshStatus() {
		this.pushEvent("player_status", {}, (reply) => {
			if (!reply.ok) {
				if (reply.error) this.setStatus(reply.error, "error");
				return;
			}

			const status = reply.status;
			this.cacheEl.textContent = `${status.cached_files} files · ${status.generated_segments} generated`;
			if (status.last_error) this.setStatus(status.last_error, "error");
		});
	},

	populateQuality(hls) {
		this.qualitySelect.innerHTML = "";
		this.qualitySelect.append(new Option("Auto (adaptive)", "-1"));

		hls.levels.forEach((level, index) => {
			const match = this.session.qualities.find(
				(quality) =>
					quality.width === level.width && quality.height === level.height,
			);
			const label = match ? match.label : `${level.height}p`;
			this.qualitySelect.append(
				new Option(`${label} · ${Math.round(level.bitrate / 1000)} kbps`, String(index)),
			);
		});

		this.qualitySelect.value = String(hls.currentLevel);
		this.qualitySelect.onchange = () => {
			const level = Number(this.qualitySelect.value);
			hls.currentLevel = level;
			hls.loadLevel = level;
			this.setStatus(
				level === -1
					? "Adaptive quality"
					: `Pinned to ${this.qualitySelect.selectedOptions[0].textContent}`,
			);
		};
	},

	populateAudio(hls) {
		this.audioSelect.innerHTML = "";

		hls.audioTracks.forEach((track, index) => {
			this.audioSelect.append(
				new Option(track.name || `Audio ${index + 1}`, String(index)),
			);
		});

		this.audioSelect.value = String(hls.audioTrack);
		this.audioSelect.disabled = hls.audioTracks.length <= 1;
		this.audioSelect.onchange = () => {
			hls.audioTrack = Number(this.audioSelect.value);
			this.setStatus(`Audio: ${this.audioSelect.selectedOptions[0].textContent}`);
		};
	},

	populateSubtitles(hls) {
		this.subtitleSelect.innerHTML = "";
		this.subtitleSelect.append(new Option("Off", "-1"));

		hls.subtitleTracks.forEach((track, index) => {
			this.subtitleSelect.append(
				new Option(track.name || `Subtitle ${index + 1}`, String(index)),
			);
		});

		this.subtitleSelect.value = "-1";
		this.subtitleSelect.disabled = hls.subtitleTracks.length === 0;
		this.subtitleSelect.onchange = () => {
			const track = Number(this.subtitleSelect.value);
			hls.subtitleDisplay = track !== -1;
			hls.subtitleTrack = track;
			this.setStatus(
				track === -1
					? "Subtitles off"
					: `Subtitles: ${this.subtitleSelect.selectedOptions[0].textContent}`,
			);
		};
	},

	disableHlsControls() {
		this.qualitySelect.innerHTML = "";
		this.qualitySelect.append(new Option("Native HLS", "native"));
		this.qualitySelect.disabled = true;
		this.audioSelect.innerHTML = "";
		this.audioSelect.append(new Option("Browser controlled", "native"));
		this.audioSelect.disabled = true;
		this.subtitleSelect.innerHTML = "";
		this.subtitleSelect.append(new Option("Browser controlled", "native"));
		this.subtitleSelect.disabled = true;
	},

	async boot() {
		try {
			const Hls = await loadHls(this.hlsScriptUrl);
			if (this.disposed) return;

			if (!Hls.isSupported()) {
				if (this.video.canPlayType("application/vnd.apple.mpegurl")) {
					this.video.src = this.session.master_url;
					this.disableHlsControls();
					this.setStatus("Ready");
				} else {
					this.setStatus("This browser does not support HLS playback", "error");
				}
				return;
			}

			const hls = new Hls({
				enableWorker: true,
				lowLatencyMode: false,
				backBufferLength: 120,
				maxBufferLength: 36,
				maxMaxBufferLength: 90,
			});

			this.hls = hls;
			window.watchClubHls = hls;
			hls.loadSource(this.session.master_url);
			hls.attachMedia(this.video);

			hls.on(Hls.Events.MANIFEST_PARSED, () => {
				this.populateQuality(hls);
				this.setStatus("Ready");
			});
			hls.on(Hls.Events.AUDIO_TRACKS_UPDATED, () => this.populateAudio(hls));
			hls.on(Hls.Events.SUBTITLE_TRACKS_UPDATED, () => this.populateSubtitles(hls));
			hls.on(Hls.Events.LEVEL_SWITCHED, (_event, data) => {
				if (hls.currentLevel === -1 && hls.levels[data.level]) {
					this.setStatus(`Auto · ${hls.levels[data.level].height}p`);
				}
			});
			hls.on(Hls.Events.ERROR, (_event, data) => {
				if (!data.fatal) return;

				this.setStatus(`${data.type}: ${data.details}`, "error");

				if (data.type === Hls.ErrorTypes.NETWORK_ERROR) {
					hls.startLoad();
				} else if (data.type === Hls.ErrorTypes.MEDIA_ERROR) {
					hls.recoverMediaError();
				} else {
					hls.destroy();
				}
			});
		} catch (_error) {
			if (this.video.canPlayType("application/vnd.apple.mpegurl")) {
				this.video.src = this.session.master_url;
				this.disableHlsControls();
				this.setStatus("Ready");
			} else {
				this.setStatus("Could not load hls.js", "error");
			}
		}
	},

	stopSession() {
		if (this.stopped) return;
		this.stopped = true;
		this.pushEvent("player_stop", {}, () => {});
	},
};

export default { Player };
