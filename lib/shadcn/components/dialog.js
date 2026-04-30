// Hook for the <.dialog> component (lib/watch_club_web/components/ui/dialog.ex).
// Wires native <dialog> open/close to the trigger slot and to any
// descendant marked `data-dialog-close`. Click-outside closes via the
// `dialog` element's own `cancel` event when the user clicks the backdrop.

function setup() {
	this.dialog = document.getElementById(`${this.el.id}-content`);
	this.trigger = this.el.querySelector('[data-slot="dialog-trigger"]');
	this.onTriggerClick = this.onTriggerClick.bind(this);
	this.onContentClick = this.onContentClick.bind(this);
	this.onBackdropClick = this.onBackdropClick.bind(this);

	this.trigger?.addEventListener("click", this.onTriggerClick);
	this.dialog?.addEventListener("click", this.onContentClick);
	this.dialog?.addEventListener("click", this.onBackdropClick);
}

function teardown() {
	this.trigger?.removeEventListener("click", this.onTriggerClick);
	this.dialog?.removeEventListener("click", this.onContentClick);
	this.dialog?.removeEventListener("click", this.onBackdropClick);
}

export const DialogHook = {
	mounted() {
		setup.call(this);
		if (this.dialog?.hasAttribute("open")) {
			// server-rendered with `open` -> upgrade to modal
			this.dialog.removeAttribute("open");
			this.dialog.showModal();
		}
	},
	updated() {
		teardown.call(this);
		setup.call(this);
	},
	destroyed() {
		teardown.call(this);
	},
	onTriggerClick(e) {
		e.preventDefault();
		this.dialog.showModal();
	},
	onContentClick(e) {
		if (e.target.closest("[data-dialog-close]")) {
			this.dialog.close();
		}
	},
	onBackdropClick(e) {
		// <dialog> itself receives clicks on its backdrop. The content is a
		// descendant — so a click directly on the <dialog> means backdrop.
		if (e.target === this.dialog) {
			const r = this.dialog.getBoundingClientRect();
			const inside =
				e.clientX >= r.left &&
				e.clientX <= r.right &&
				e.clientY >= r.top &&
				e.clientY <= r.bottom;
			if (!inside) this.dialog.close();
		}
	},
};
