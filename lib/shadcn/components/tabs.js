// Hook for the <.tabs> component (lib/watch_club_web/components/ui/tabs.ex).
// Drives client-side tab switching, keyboard navigation, and roving
// tabindex per the WAI-ARIA Tabs pattern.

function setup() {
	this.list = this.el.querySelector('[data-slot="tabs-list"]');
	this.onClick = this.onClick.bind(this);
	this.onKey = this.onKey.bind(this);
	this.list.addEventListener("click", this.onClick);
	this.list.addEventListener("keydown", this.onKey);
}

function teardown() {
	this.list?.removeEventListener("click", this.onClick);
	this.list?.removeEventListener("keydown", this.onKey);
}

function triggers(el) {
	return Array.from(
		el.querySelectorAll(
			':scope > [data-slot="tabs-list"] > [data-slot="tabs-trigger"]',
		),
	);
}

function panels(el) {
	return Array.from(el.querySelectorAll(':scope > [data-slot="tabs-content"]'));
}

function activate(el, id) {
	triggers(el).forEach((t) => {
		const active = t.getAttribute("data-tab-id") === id;
		t.setAttribute("data-state", active ? "active" : "inactive");
		if (active) t.setAttribute("data-active", "true");
		else t.removeAttribute("data-active");
		t.setAttribute("aria-selected", active ? "true" : "false");
		t.setAttribute("tabindex", active ? "0" : "-1");
	});
	panels(el).forEach((p) => {
		const active = p.getAttribute("data-tab-id") === id;
		p.setAttribute("data-state", active ? "active" : "inactive");
		if (active) p.removeAttribute("hidden");
		else p.setAttribute("hidden", "");
	});
}

export const TabsHook = {
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
	onClick(e) {
		const t = e.target.closest('[data-slot="tabs-trigger"]');
		if (!t || t.disabled) return;
		activate(this.el, t.getAttribute("data-tab-id"));
		t.focus();
	},
	onKey(e) {
		const orientation =
			this.el.getAttribute("data-orientation") || "horizontal";
		const t = e.target.closest('[data-slot="tabs-trigger"]');
		if (!t) return;

		const all = triggers(this.el).filter((x) => !x.disabled);
		const idx = all.indexOf(t);
		let next = null;

		const horizontal = orientation === "horizontal";
		if (
			(horizontal && e.key === "ArrowRight") ||
			(!horizontal && e.key === "ArrowDown")
		) {
			next = all[(idx + 1) % all.length];
		} else if (
			(horizontal && e.key === "ArrowLeft") ||
			(!horizontal && e.key === "ArrowUp")
		) {
			next = all[(idx - 1 + all.length) % all.length];
		} else if (e.key === "Home") {
			next = all[0];
		} else if (e.key === "End") {
			next = all[all.length - 1];
		} else {
			return;
		}

		e.preventDefault();
		activate(this.el, next.getAttribute("data-tab-id"));
		next.focus();
	},
};
