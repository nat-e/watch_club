// Hook for the <.avatar> component (lib/watch_club_web/components/ui/avatar.ex).
// Swaps the avatar image in once it loads, keeps the fallback if it errors.
// Registered manually in assets/js/app.js and assets/js/storybook.js.

function attach() {
	const img = this.el.querySelector('[data-slot="avatar-image"]');
	if (!img) return;

	if (img.complete) {
		this.el.setAttribute(
			"data-status",
			img.naturalWidth > 0 ? "loaded" : "error",
		);
		return;
	}

	// Attach listeners FIRST to avoid races: if load/error fires
	// between a `complete` check and addEventListener, we'd miss it.
	img.addEventListener(
		"load",
		() => {
			this.el.setAttribute("data-status", "loaded");
		},
		{ once: true },
	);
	img.addEventListener(
		"error",
		() => {
			this.el.setAttribute("data-status", "error");
		},
		{ once: true },
	);

	const delay = parseInt(
		this.el.getAttribute("data-fallback-delay") || "0",
		10,
	);
	if (delay > 0) {
		setTimeout(() => {
			if (this.el.getAttribute("data-status") === "loading-delayed") {
				this.el.setAttribute("data-status", "loading");
			}
		}, delay);
	}
}

export default {
	mounted() {
		attach.call(this);
	},
	// Re-run on every LiveView patch — if the image src changed, morph has
	// replaced the <img> element so the listeners attached on the previous
	// mount/update are gone with it. Server-rendered HTML resets
	// `data-status="loading"`, so we just re-attach to the new <img>.
	updated() {
		attach.call(this);
	},
};
