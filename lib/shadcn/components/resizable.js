// Hook for the <.resizable_panels> component
// (lib/watch_club_web/components/ui/resizable.ex). Drags the handle to
// resize the two adjacent panels (only horizontal/vertical pairs are
// supported — no nested groups).

function setup() {
	this.handles = Array.from(
		this.el.querySelectorAll('[data-slot="resizable-handle"]'),
	);
	this.handles.forEach((h) => {
		h.addEventListener("pointerdown", this.onPointerDown);
	});
}

function teardown() {
	this.handles?.forEach((h) => {
		h.removeEventListener("pointerdown", this.onPointerDown);
	});
	document.removeEventListener("pointermove", this.onPointerMove);
	document.removeEventListener("pointerup", this.onPointerUp);
}

export const ResizableHook = {
	mounted() {
		this.onPointerDown = this.onPointerDown.bind(this);
		this.onPointerMove = this.onPointerMove.bind(this);
		this.onPointerUp = this.onPointerUp.bind(this);
		setup.call(this);
	},
	updated() {
		teardown.call(this);
		setup.call(this);
	},
	destroyed() {
		teardown.call(this);
	},
	onPointerDown(e) {
		e.preventDefault();
		this.handle = e.currentTarget;
		this.before = this.handle.previousElementSibling;
		this.after = this.handle.nextElementSibling;
		if (!this.before || !this.after) return;
		const r = this.el.getBoundingClientRect();
		this.size = this.el.dataset.direction === "vertical" ? r.height : r.width;
		document.addEventListener("pointermove", this.onPointerMove);
		document.addEventListener("pointerup", this.onPointerUp);
	},
	onPointerMove(e) {
		if (!this.before || !this.after) return;
		const r = this.el.getBoundingClientRect();
		const vertical = this.el.dataset.direction === "vertical";
		const offset = vertical ? e.clientY - r.top : e.clientX - r.left;
		const totalPanels =
			this.before.getBoundingClientRect()[vertical ? "height" : "width"] +
				this.after.getBoundingClientRect()[vertical ? "height" : "width"] ||
			this.size;
		const beforePct = Math.max(0, Math.min(100, (offset / this.size) * 100));
		const afterPct = 100 - beforePct;
		void totalPanels;
		this.before.style.flex = `1 1 ${beforePct}%`;
		this.after.style.flex = `1 1 ${afterPct}%`;
	},
	onPointerUp() {
		document.removeEventListener("pointermove", this.onPointerMove);
		document.removeEventListener("pointerup", this.onPointerUp);
		this.handle = null;
		this.before = null;
		this.after = null;
	},
};
