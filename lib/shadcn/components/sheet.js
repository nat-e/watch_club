// Hook for the <.sheet> component (lib/watch_club_web/components/ui/sheet.ex).
// Identical pattern to dialog.js — wires trigger/close to native <dialog>
// API. The slide animation comes purely from CSS based on `data-side`.

function setup() {
	this.dialog = document.getElementById(`${this.el.id}-content`);
	this.trigger = this.el.querySelector('[data-slot="sheet-trigger"]');
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

export const SheetHook = {
	mounted() {
		setup.call(this);
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
		if (e.target.closest("[data-sheet-close]")) {
			this.dialog.close();
		}
	},
	onBackdropClick(e) {
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
