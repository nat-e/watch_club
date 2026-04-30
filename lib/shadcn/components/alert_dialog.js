// Hook for the <.alert_dialog> component.
// Wires trigger -> showModal(), cancel/action -> close(). Disables
// click-outside-to-close (a defining feature of alert dialogs vs dialogs).

function setup() {
	this.dialog = document.getElementById(`${this.el.id}-content`);
	this.trigger = this.el.querySelector('[data-slot="alert-dialog-trigger"]');
	this.onTriggerClick = this.onTriggerClick.bind(this);
	this.onContentClick = this.onContentClick.bind(this);
	this.onCancel = this.onCancel.bind(this);

	this.trigger?.addEventListener("click", this.onTriggerClick);
	this.dialog?.addEventListener("click", this.onContentClick);
	// Suppress backdrop ESC dismissal? No — ESC should still close on alert
	// dialog (browser default). We only block click-outside.
	this.dialog?.addEventListener("cancel", this.onCancel);
}

function teardown() {
	this.trigger?.removeEventListener("click", this.onTriggerClick);
	this.dialog?.removeEventListener("click", this.onContentClick);
	this.dialog?.removeEventListener("cancel", this.onCancel);
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
	onTriggerClick(e) {
		e.preventDefault();
		this.dialog.showModal();
	},
	onContentClick(e) {
		if (
			e.target.closest("[data-alert-dialog-cancel]") ||
			e.target.closest("[data-alert-dialog-action]")
		) {
			this.dialog.close();
		}
		// No backdrop click handling — alert dialogs cannot be dismissed by
		// clicking outside.
	},
	onCancel(e) {
		// Allow ESC to close, the default browser behavior.
		void e;
	},
};
