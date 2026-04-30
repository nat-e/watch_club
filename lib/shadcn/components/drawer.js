// Hook for the <.drawer> component. Same trigger/close logic as
// sheet/dialog. Touch drag-to-dismiss not implemented.

function setup() {
	this.dialog = document.getElementById(`${this.el.id}-content`);
	this.trigger = this.el.querySelector('[data-slot="drawer-trigger"]');
	this.onTriggerClick = this.onTriggerClick.bind(this);
	this.onContentClick = this.onContentClick.bind(this);

	this.trigger?.addEventListener("click", this.onTriggerClick);
	this.dialog?.addEventListener("click", this.onContentClick);
}

function teardown() {
	this.trigger?.removeEventListener("click", this.onTriggerClick);
	this.dialog?.removeEventListener("click", this.onContentClick);
}

export const DrawerHook = {
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
		if (e.target.closest("[data-drawer-close]")) {
			this.dialog.close();
			return;
		}
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
