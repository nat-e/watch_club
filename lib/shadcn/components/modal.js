// Hook for the <.modal> component (lib/shadcn/components/modal.ex).
// Wires native <dialog> open/close: descendants marked `data-modal-close`
// dismiss the modal, clicks on the backdrop close it, and the native
// `close` event runs the optional `data-on-close` JS command (e.g. to
// patch the URL for URL-driven modals).
function setup() {
	this.onContentClick = this.onContentClick.bind(this);
	// this.onBackdropClick = this.onBackdropClick.bind(this);
	this.onClose = this.onClose.bind(this);

	this.el.addEventListener("click", this.onContentClick);
	// this.el.addEventListener("click", this.onBackdropClick);
	this.el.addEventListener("close", this.onClose);
}

function teardown() {
	this.el.removeEventListener("click", this.onContentClick);
	// this.el.removeEventListener("click", this.onBackdropClick);
	this.el.removeEventListener("close", this.onClose);
}

export const ModalHook = {
	mounted() {
		setup.call(this);
		if (this.el.hasAttribute("open")) {
			// server-rendered with `open` -> upgrade to modal
			this.el.removeAttribute("open");
			this.el.showModal();
		}
	},
	updated() {
		teardown.call(this);
		setup.call(this);
	},
	destroyed() {
		teardown.call(this);
	},
	onContentClick(e) {
		if (e.target.closest("[data-modal-close]")) {
			this.el.close();
		}
	},
	// onBackdropClick(e) {
	// 	// <dialog> itself receives clicks on its backdrop. The content is a
	// 	// descendant — so a click directly on the <dialog> means backdrop.
	// 	if (e.target === this.el) {
	// 		const r = this.el.getBoundingClientRect();
	// 		const inside =
	// 			e.clientX >= r.left &&
	// 			e.clientX <= r.right &&
	// 			e.clientY >= r.top &&
	// 			e.clientY <= r.bottom;
	// 		if (!inside) {
	// 			this.el.close();
	// 		}
	// 	}
	// },
	onClose() {
		const js = this.el.getAttribute("data-on-close");
		if (js) {
			this.liveSocket.execJS(this.el, js);
		}
	},
};
