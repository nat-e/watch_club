// Hook for the <.alert_dialog> component.
// Wires trigger -> showModal(), cancel/action -> close(). Disables
// click-outside-to-close (a defining feature of alert dialogs vs dialogs).

function setup() {
	this.onContentClick = this.onContentClick.bind(this);
	this.onCancel = this.onCancel.bind(this);

	this.el.addEventListener("click", this.onContentClick);
	// Suppress backdrop ESC dismissal? No — ESC should still close on alert
	// dialog (browser default). We only block click-outside.
	this.el.addEventListener("cancel", this.onCancel);
}

function teardown() {
	this.el.removeEventListener("click", this.onContentClick);
	this.el.removeEventListener("cancel", this.onCancel);
}

export const AlertDialogHook = {
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
	onContentClick(e) {
		if (
			e.target.closest("[data-alert-dialog-cancel]") ||
			e.target.closest("[data-alert-dialog-action]")
		) {
			this.el.close();
		}
		// No backdrop click handling — alert dialogs cannot be dismissed by
		// clicking outside.
	},
	onCancel(e) {
		// Allow ESC to close, the default browser behavior.
		void e;
	},
};
