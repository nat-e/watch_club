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

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

const formatTime = (value) => {
	if (!Number.isFinite(value)) return "0:00";

	const total = Math.max(0, Math.floor(value));
	const hours = Math.floor(total / 3600);
	const minutes = Math.floor((total % 3600) / 60);
	const seconds = String(total % 60).padStart(2, "0");

	if (hours > 0) return `${hours}:${String(minutes).padStart(2, "0")}:${seconds}`;
	return `${minutes}:${seconds}`;
};

const Player = {
	mounted() {
		this.session = JSON.parse(this.el.dataset.session);
		this.hlsScriptUrl = this.el.dataset.hlsSrc || defaultHlsScriptUrl;
		this.video = this.el.querySelector("[data-player-video]");
		this.surface = this.el.querySelector("[data-player-surface]");
		this.controls = this.el.querySelector("[data-player-controls]");
		this.timeline = this.el.querySelector("[data-player-timeline]");
		this.progressBar = this.el.querySelector("[data-player-progress-bar]");
		this.bufferedBar = this.el.querySelector("[data-player-buffered-bar]");
		this.timelineThumb = this.el.querySelector("[data-player-timeline-thumb]");
		this.currentTimeEl = this.el.querySelector("[data-player-current-time]");
		this.durationEl = this.el.querySelector("[data-player-duration]");
		this.statusEl = this.el.querySelector("[data-player-status]");
		this.playIcons = Array.from(this.el.querySelectorAll("[data-player-play-icon]"));
		this.pauseIcons = Array.from(this.el.querySelectorAll("[data-player-pause-icon]"));
		this.mutedIcons = Array.from(this.el.querySelectorAll("[data-player-muted-icon]"));
		this.unmutedIcons = Array.from(this.el.querySelectorAll("[data-player-unmuted-icon]"));
		this.fullscreenEnterIcons = Array.from(
			this.el.querySelectorAll("[data-player-fullscreen-enter-icon]"),
		);
		this.fullscreenExitIcons = Array.from(
			this.el.querySelectorAll("[data-player-fullscreen-exit-icon]"),
		);
		this.menuButtons = Array.from(this.el.querySelectorAll("[data-player-menu-button]"));
		this.menuPanels = Array.from(this.el.querySelectorAll("[data-player-menu-panel]"));

		this.abortController = new AbortController();
		this.hideControlsTimer = null;
		this.progressFrame = null;
		this.openMenuName = null;
		this.controlsHover = false;
		this.dragging = false;
		this.dragTime = null;
		this.disposed = false;
		this.stopped = false;
		this.nativeHls = false;

		this.restoreLocalPreferences();
		this.bindDomEvents();
		this.updatePlaybackUi();
		this.updateVolumeUi();
		this.updateFullscreenUi();
		this.boot();
	},

	destroyed() {
		this.cleanup();
	},

	cleanup() {
		if (this.disposed) return;
		this.disposed = true;
		window.clearTimeout(this.hideControlsTimer);
		window.cancelAnimationFrame(this.progressFrame);
		this.abortController.abort();
		if (this.hls) this.hls.destroy();
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
					this.handleCommand(button.dataset.playerCommand, button);
				},
				{ signal },
			);
		});

		this.menuButtons.forEach((button) => {
			button.addEventListener(
				"click",
				(event) => {
					event.preventDefault();
					event.stopPropagation();
					if (button.disabled || button.getAttribute("aria-disabled") === "true") return;
					this.toggleMenu(button.dataset.playerMenuButton);
				},
				{ signal },
			);
		});

		this.menuPanels.forEach((panel) => {
			panel.addEventListener("click", (event) => event.stopPropagation(), { signal });
		});

		this.el.querySelectorAll("[data-player-quality-option]").forEach((option) => {
			option.addEventListener(
				"click",
				(event) => {
					event.preventDefault();
					event.stopPropagation();
					this.selectQuality(option);
				},
				{ signal },
			);
		});

		this.el.querySelectorAll("[data-player-audio-option]").forEach((option) => {
			option.addEventListener(
				"click",
				(event) => {
					event.preventDefault();
					event.stopPropagation();
					this.selectAudio(option);
				},
				{ signal },
			);
		});

		this.el.querySelectorAll("[data-player-subtitle-option]").forEach((option) => {
			option.addEventListener(
				"click",
				(event) => {
					event.preventDefault();
					event.stopPropagation();
					this.selectSubtitle(option);
				},
				{ signal },
			);
		});

		this.surface.addEventListener(
			"pointerdown",
			(event) => {
				this.lastSurfacePointerType = event.pointerType;
			},
			{ signal },
		);
		this.surface.addEventListener(
			"click",
			() => {
				if (this.openMenuName) {
					this.closeMenu();
					return;
				}

				const wasVisible = this.el.dataset.controls === "visible";
				if (this.lastSurfacePointerType === "touch") {
					if (wasVisible && !this.video.paused) this.hideControls();
					else this.showControls();
					return;
				}

				this.showControls();
				this.togglePlay();
			},
			{ signal },
		);

		this.el.addEventListener(
			"pointermove",
			(event) => {
				if (event.pointerType !== "touch") this.showControls();
			},
			{ signal },
		);

		this.controls.addEventListener(
			"pointerenter",
			() => {
				this.controlsHover = true;
				this.clearHideControlsTimer();
			},
			{ signal },
		);
		this.controls.addEventListener(
			"pointerleave",
			() => {
				this.controlsHover = false;
				this.scheduleHideControls();
			},
			{ signal },
		);

		this.timeline.addEventListener("pointerdown", (event) => this.startTimelineDrag(event), {
			signal,
		});
		this.timeline.addEventListener("pointermove", (event) => this.moveTimelineDrag(event), {
			signal,
		});
		this.timeline.addEventListener("pointerup", (event) => this.finishTimelineDrag(event), {
			signal,
		});
		this.timeline.addEventListener("pointercancel", () => this.cancelTimelineDrag(), {
			signal,
		});
		this.timeline.addEventListener("keydown", (event) => this.handleTimelineKeydown(event), {
			signal,
		});

		this.video.addEventListener("loadedmetadata", () => this.updatePlaybackUi(), { signal });
		this.video.addEventListener("durationchange", () => this.updatePlaybackUi(), { signal });
		this.video.addEventListener("timeupdate", () => this.updatePlaybackUi(), { signal });
		this.video.addEventListener("progress", () => this.updatePlaybackUi(), { signal });
		this.video.addEventListener(
			"play",
			() => {
				this.el.dataset.playing = "true";
				this.el.dataset.ended = "false";
				this.updatePlaybackUi();
				this.startProgressLoop();
				this.scheduleHideControls();
			},
			{ signal },
		);
		this.video.addEventListener(
			"pause",
			() => {
				this.el.dataset.playing = "false";
				this.updatePlaybackUi();
				this.showControls({ persist: true });
			},
			{ signal },
		);
		this.video.addEventListener(
			"ended",
			() => {
				this.el.dataset.playing = "false";
				this.el.dataset.ended = "true";
				this.updatePlaybackUi();
				this.showControls({ persist: true });
			},
			{ signal },
		);
		this.video.addEventListener("waiting", () => this.setBuffering(true), { signal });
		this.video.addEventListener("stalled", () => this.setBuffering(true), { signal });
		this.video.addEventListener("playing", () => this.setBuffering(false), { signal });
		this.video.addEventListener("canplay", () => this.setBuffering(false), { signal });
		this.video.addEventListener("volumechange", () => this.updateVolumeUi(), { signal });
		this.video.addEventListener(
			"error",
			() => this.setStatus("The video could not be played", "error"),
			{ signal },
		);

		window.addEventListener("keydown", (event) => this.handleGlobalKeydown(event), { signal });
		window.addEventListener("pagehide", () => this.stopSession(), { signal });
		document.addEventListener("fullscreenchange", () => this.updateFullscreenUi(), { signal });
		document.addEventListener(
			"click",
			(event) => {
				if (this.openMenuName && !this.el.contains(event.target)) this.closeMenu();
			},
			{ signal },
		);
	},

	restoreLocalPreferences() {
		const storedVolume = window.localStorage.getItem("watch-club:player-volume");
		const storedMuted = window.localStorage.getItem("watch-club:player-muted");

		if (storedVolume === "0") {
			window.localStorage.removeItem("watch-club:player-volume");
			window.localStorage.removeItem("watch-club:player-muted");
			this.lastNonZeroVolume = 1;
			return;
		}

		if (storedVolume !== null) {
			const volume = Number(storedVolume);
			if (Number.isFinite(volume) && volume > 0) this.video.volume = clamp(volume, 0, 1);
		}

		this.lastNonZeroVolume = this.video.volume > 0 ? this.video.volume : 1;
		this.video.muted = storedMuted === "true";
	},

	handleCommand(command, element) {
		switch (command) {
			case "back":
				if (window.history.length > 1) window.history.back();
				else window.location.assign("/");
				break;
			case "play-toggle":
				this.togglePlay();
				break;
			case "seek-back":
			case "seek-forward":
				this.seekBy(Number(element.dataset.seconds || 0));
				break;
			case "mute-toggle":
				this.toggleMute();
				break;
			case "fullscreen-toggle":
				this.toggleFullscreen();
				break;
		}
	},

	async boot() {
		try {
			const Hls = await loadHls(this.hlsScriptUrl);
			if (this.disposed) return;

			if (!Hls.isSupported()) {
				if (this.video.canPlayType("application/vnd.apple.mpegurl")) {
					this.nativeHls = true;
					this.video.src = this.session.master_url;
					this.disableAdaptiveMenus("Native HLS");
					this.setStatus("Ready");
					this.setBuffering(false);
				} else {
					this.setStatus("This browser does not support HLS playback", "error");
					this.setBuffering(false);
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
				this.setStatus("Ready");
				this.setBuffering(false);
				this.updateQualitySelection("auto");
			});
			hls.on(Hls.Events.AUDIO_TRACKS_UPDATED, () => this.syncAudioAvailability());
			hls.on(Hls.Events.SUBTITLE_TRACKS_UPDATED, () => this.syncSubtitleAvailability());
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
				this.nativeHls = true;
				this.video.src = this.session.master_url;
				this.disableAdaptiveMenus("Native HLS");
				this.setStatus("Ready");
				this.setBuffering(false);
			} else {
				this.setStatus("Could not load hls.js", "error");
				this.setBuffering(false);
			}
		}
	},

	disableAdaptiveMenus(label) {
		this.el.querySelectorAll("[data-player-quality-option]").forEach((option) => {
			option.disabled = true;
		});
		const auto = this.el.querySelector("[data-player-quality-option='auto'] span:last-child");
		if (auto) auto.textContent = label;
		this.el.querySelectorAll("[data-player-audio-option], [data-player-subtitle-option]").forEach(
			(option) => {
				option.disabled = true;
			},
		);
	},

	togglePlay() {
		this.closeMenu();
		if (this.video.paused || this.video.ended) {
			this.video.play().catch((error) => {
				if (error.name !== "AbortError") this.setStatus("Playback needs a user gesture", "error");
			});
		} else {
			this.video.pause();
		}
	},

	seekBy(seconds) {
		const duration = this.getDuration();
		if (!duration) return;
		this.video.currentTime = clamp(this.video.currentTime + seconds, 0, duration);
		this.updatePlaybackUi();
		this.showControls();
	},

	seekTo(time) {
		const duration = this.getDuration();
		if (!duration) return;
		this.video.currentTime = clamp(time, 0, duration);
		this.updatePlaybackUi();
	},

	getDuration() {
		return Number.isFinite(this.video.duration) ? this.video.duration : this.session.duration;
	},

	startProgressLoop() {
		if (this.progressFrame) return;
		const tick = () => {
			this.updatePlaybackUi();
			if (!this.video.paused && !this.video.ended && !this.disposed) {
				this.progressFrame = window.requestAnimationFrame(tick);
			} else {
				this.progressFrame = null;
			}
		};
		this.progressFrame = window.requestAnimationFrame(tick);
	},

	updatePlaybackUi(timeOverride = null) {
		const duration = this.getDuration();
		const current = timeOverride ?? this.video.currentTime ?? 0;
		const ratio = duration > 0 ? clamp(current / duration, 0, 1) : 0;
		const percent = `${ratio * 100}%`;

		this.progressBar.style.width = percent;
		this.timelineThumb.style.left = percent;
		this.currentTimeEl.textContent = formatTime(current);
		this.durationEl.textContent = formatTime(duration);
		this.timeline.setAttribute("aria-valuemax", String(Math.floor(duration || 0)));
		this.timeline.setAttribute("aria-valuenow", String(Math.floor(current || 0)));
		this.timeline.setAttribute(
			"aria-valuetext",
			`${formatTime(current)} of ${formatTime(duration)}`,
		);

		this.updateBufferedUi(duration);
		this.updatePlayPauseUi();
	},

	updateBufferedUi(duration = this.getDuration()) {
		if (!duration || !this.video.buffered?.length) {
			this.bufferedBar.style.width = "0%";
			return;
		}

		let end = 0;
		for (let index = 0; index < this.video.buffered.length; index += 1) {
			const start = this.video.buffered.start(index);
			const bufferedEnd = this.video.buffered.end(index);
			if (this.video.currentTime >= start && this.video.currentTime <= bufferedEnd) {
				end = bufferedEnd;
				break;
			}
			end = Math.max(end, bufferedEnd);
		}

		this.bufferedBar.style.width = `${clamp(end / duration, 0, 1) * 100}%`;
	},

	updatePlayPauseUi() {
		const playing = !this.video.paused && !this.video.ended;
		this.el.dataset.playing = playing ? "true" : "false";
		this.playIcons.forEach((icon) => icon.classList.toggle("hidden", playing));
		this.pauseIcons.forEach((icon) => icon.classList.toggle("hidden", !playing));
	},

	toggleMute() {
		const effectivelyMuted = this.video.muted || this.video.volume === 0;

		if (effectivelyMuted) {
			this.video.muted = false;
			if (this.video.volume === 0) this.video.volume = this.lastNonZeroVolume || 1;
		} else {
			this.video.muted = true;
		}

		this.updateVolumeUi();
	},

	updateVolumeUi() {
		if (this.video.volume > 0) this.lastNonZeroVolume = this.video.volume;

		const muted = this.video.muted || this.video.volume === 0;
		this.el.dataset.muted = muted ? "true" : "false";
		this.mutedIcons.forEach((icon) => icon.classList.toggle("hidden", !muted));
		this.unmutedIcons.forEach((icon) => icon.classList.toggle("hidden", muted));
		window.localStorage.setItem("watch-club:player-volume", String(this.video.volume));
		window.localStorage.setItem("watch-club:player-muted", String(this.video.muted));
	},

	setBuffering(buffering) {
		this.el.dataset.buffering = buffering ? "true" : "false";
	},

	setStatus(message, kind = "info") {
		if (!this.statusEl) return;
		this.statusEl.textContent = message;
		this.statusEl.dataset.kind = kind;
		this.statusEl.classList.toggle("text-danger", kind === "error");
	},

	startTimelineDrag(event) {
		event.preventDefault();
		this.dragging = true;
		this.timeline.dataset.dragging = "true";
		this.timeline.setPointerCapture?.(event.pointerId);
		this.showControls({ persist: true });
		this.dragTime = this.timeFromPointer(event);
		this.updatePlaybackUi(this.dragTime);
	},

	moveTimelineDrag(event) {
		if (!this.dragging) return;
		event.preventDefault();
		this.dragTime = this.timeFromPointer(event);
		this.updatePlaybackUi(this.dragTime);
	},

	finishTimelineDrag(event) {
		if (!this.dragging) return;
		event.preventDefault();
		this.dragTime = this.timeFromPointer(event);
		this.seekTo(this.dragTime);
		this.cancelTimelineDrag();
		this.scheduleHideControls();
	},

	cancelTimelineDrag() {
		this.dragging = false;
		this.dragTime = null;
		this.timeline.dataset.dragging = "false";
		this.updatePlaybackUi();
	},

	timeFromPointer(event) {
		const rect = this.timeline.getBoundingClientRect();
		const ratio = rect.width > 0 ? clamp((event.clientX - rect.left) / rect.width, 0, 1) : 0;
		return ratio * this.getDuration();
	},

	handleTimelineKeydown(event) {
		switch (event.key) {
			case "ArrowLeft":
				event.preventDefault();
				this.seekBy(-10);
				break;
			case "ArrowRight":
				event.preventDefault();
				this.seekBy(10);
				break;
			case "Home":
				event.preventDefault();
				this.seekTo(0);
				break;
			case "End":
				event.preventDefault();
				this.seekTo(this.getDuration());
				break;
		}
	},

	handleGlobalKeydown(event) {
		if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey) return;
		const target = event.target;
		const tag = target?.tagName;
		if (["INPUT", "TEXTAREA", "SELECT"].includes(tag)) return;
		if (target?.closest?.("[data-player-menu-panel]") && event.key !== "Escape") return;

		switch (event.key) {
			case " ":
				if (target?.closest?.("button")) return;
				event.preventDefault();
				this.togglePlay();
				break;
			case "k":
			case "K":
				event.preventDefault();
				this.togglePlay();
				break;
			case "ArrowLeft":
				event.preventDefault();
				this.seekBy(-10);
				break;
			case "ArrowRight":
				event.preventDefault();
				this.seekBy(10);
				break;
			case "m":
			case "M":
				event.preventDefault();
				this.toggleMute();
				break;
			case "f":
			case "F":
				event.preventDefault();
				this.toggleFullscreen();
				break;
			case "Escape":
				if (this.openMenuName) {
					event.preventDefault();
					this.closeMenu();
				} else {
					this.showControls({ persist: true });
				}
				break;
		}
	},

	toggleMenu(name) {
		if (this.openMenuName === name) this.closeMenu();
		else this.openMenu(name);
	},

	openMenu(name) {
		this.openMenuName = name;
		this.el.dataset.menu = name;
		this.menuPanels.forEach((panel) => {
			const active = panel.dataset.playerMenuPanel === name;
			panel.hidden = !active;
			if (active) {
				window.requestAnimationFrame(() => {
					const selected = panel.querySelector("[data-selected='true']");
					(selected || panel.querySelector("button"))?.focus?.();
				});
			}
		});
		this.showControls({ persist: true });
	},

	closeMenu() {
		this.openMenuName = null;
		this.el.dataset.menu = "closed";
		this.menuPanels.forEach((panel) => {
			panel.hidden = true;
		});
		this.scheduleHideControls();
	},

	showControls(opts = {}) {
		this.el.dataset.controls = "visible";
		this.clearHideControlsTimer();
		if (!opts.persist) this.scheduleHideControls();
	},

	hideControls() {
		if (this.shouldKeepControlsVisible()) return;
		this.el.dataset.controls = "hidden";
	},

	scheduleHideControls() {
		this.clearHideControlsTimer();
		if (this.shouldKeepControlsVisible()) return;
		this.hideControlsTimer = window.setTimeout(() => this.hideControls(), 3000);
	},

	clearHideControlsTimer() {
		window.clearTimeout(this.hideControlsTimer);
		this.hideControlsTimer = null;
	},

	shouldKeepControlsVisible() {
		return (
			this.video.paused ||
			this.video.ended ||
			this.openMenuName ||
			this.controlsHover ||
			this.dragging ||
			this.el.dataset.buffering === "true"
		);
	},

	findLevelForQuality(option) {
		if (!this.hls) return -1;
		const width = Number(option.dataset.qualityWidth);
		const height = Number(option.dataset.qualityHeight);
		let index = this.hls.levels.findIndex((level) => level.width === width && level.height === height);
		if (index === -1) index = this.hls.levels.findIndex((level) => level.height === height);
		return index;
	},

	selectQuality(option) {
		if (option.disabled) return;
		const value = option.dataset.playerQualityOption;
		if (this.hls) {
			if (value === "auto") {
				this.hls.currentLevel = -1;
				this.hls.loadLevel = -1;
				this.setStatus("Adaptive quality");
			} else {
				const level = this.findLevelForQuality(option);
				if (level !== -1) {
					this.hls.currentLevel = level;
					this.hls.loadLevel = level;
					this.setStatus(`Pinned to ${option.textContent.trim()}`);
				}
			}
		}
		this.updateQualitySelection(value);
		this.closeMenu();
	},

	updateQualitySelection(value) {
		this.el.querySelectorAll("[data-player-quality-option]").forEach((option) => {
			const selected = option.dataset.playerQualityOption === value;
			option.dataset.selected = selected ? "true" : "false";
			option.setAttribute("aria-checked", selected ? "true" : "false");
		});
	},

	selectAudio(option) {
		if (option.disabled) return;
		const index = Number(option.dataset.playerAudioOption);
		if (this.hls && Number.isInteger(index)) this.hls.audioTrack = index;
		this.updateOptionSelection("[data-player-audio-option]", option);
		this.setStatus(`Audio: ${option.textContent.trim()}`);
		this.closeMenu();
	},

	selectSubtitle(option) {
		if (option.disabled) return;
		const index = Number(option.dataset.playerSubtitleOption);
		if (this.hls) {
			this.hls.subtitleDisplay = index !== -1;
			this.hls.subtitleTrack = index;
		} else {
			Array.from(this.video.textTracks || []).forEach((track, trackIndex) => {
				track.mode = index !== -1 && trackIndex === index ? "showing" : "disabled";
			});
		}
		this.updateOptionSelection("[data-player-subtitle-option]", option);
		this.setStatus(index === -1 ? "Subtitles off" : `Subtitles: ${option.textContent.trim()}`);
		this.closeMenu();
	},

	updateOptionSelection(selector, selectedOption) {
		this.el.querySelectorAll(selector).forEach((option) => {
			const selected = option === selectedOption;
			option.dataset.selected = selected ? "true" : "false";
			option.setAttribute("aria-checked", selected ? "true" : "false");
		});
	},

	syncAudioAvailability() {
		const disabled = !this.hls || this.hls.audioTracks.length <= 1;
		this.el.querySelectorAll("[data-player-menu-button='audio']").forEach((button) => {
			button.disabled = disabled;
		});

		const selected = this.el.querySelector(`[data-player-audio-option='${this.hls?.audioTrack ?? 0}']`);
		if (selected) this.updateOptionSelection("[data-player-audio-option]", selected);
	},

	syncSubtitleAvailability() {
		const disabled = !this.hls || this.hls.subtitleTracks.length === 0;
		this.el.querySelectorAll("[data-player-menu-button='subtitles']").forEach((button) => {
			button.disabled = disabled;
		});
	},

	async toggleFullscreen() {
		if (document.fullscreenElement === this.el) {
			await document.exitFullscreen?.();
		} else if (document.fullscreenEnabled && this.el.requestFullscreen) {
			await this.el.requestFullscreen();
		} else if (this.video.webkitEnterFullscreen) {
			this.video.webkitEnterFullscreen();
		}
		this.updateFullscreenUi();
	},

	updateFullscreenUi() {
		const fullscreen = document.fullscreenElement === this.el;
		this.el.dataset.fullscreen = fullscreen ? "true" : "false";
		this.fullscreenEnterIcons.forEach((icon) => icon.classList.toggle("hidden", fullscreen));
		this.fullscreenExitIcons.forEach((icon) => icon.classList.toggle("hidden", !fullscreen));
	},

	stopSession() {
		if (this.stopped) return;
		this.stopped = true;
		this.pushEvent("player_stop", {}, () => {});
	},
};

export default { Player };
