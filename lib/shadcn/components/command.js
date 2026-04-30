// Hook for the <.command> component (lib/watch_club_web/components/ui/command.ex).
// Filters items as the user types and drives keyboard navigation. Emits a
// `command:select` CustomEvent on the root when an item is chosen.

function items(el) {
	return Array.from(
		el.querySelectorAll('[data-slot="command-item"]:not([data-disabled])'),
	);
}

function visibleItems(el) {
	return items(el).filter((i) => !i.hidden);
}

function setup() {
	this.input = this.el.querySelector('[data-slot="command-input"]');
	this.empty = this.el.querySelector('[data-slot="command-empty"]');

	this.onInput = this.onInput.bind(this);
	this.onKey = this.onKey.bind(this);
	this.onClick = this.onClick.bind(this);
	this.onPointerOver = this.onPointerOver.bind(this);

	this.input?.addEventListener("input", this.onInput);
	this.input?.addEventListener("keydown", this.onKey);
	this.el.addEventListener("click", this.onClick);
	this.el.addEventListener("pointerover", this.onPointerOver);

	this.filter("");
}

function teardown() {
	this.input?.removeEventListener("input", this.onInput);
	this.input?.removeEventListener("keydown", this.onKey);
	this.el.removeEventListener("click", this.onClick);
	this.el.removeEventListener("pointerover", this.onPointerOver);
}

function setActive(el, item) {
	items(el).forEach((i) => {
		i.removeAttribute("data-active");
	});
	if (item) item.setAttribute("data-active", "true");
}

export const CommandHook = {
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
	filter(query) {
		const q = query.trim().toLowerCase();
		let visibleCount = 0;
		items(this.el).forEach((item) => {
			const value = (item.getAttribute("data-value") || "").toLowerCase();
			const text = item.textContent.toLowerCase();
			const match = !q || value.includes(q) || text.includes(q);
			item.hidden = !match;
			if (match) visibleCount++;
		});
		// Hide empty groups
		this.el.querySelectorAll('[data-slot="command-group"]').forEach((g) => {
			const anyVisible = !!g.querySelector(
				'[data-slot="command-item"]:not([hidden])',
			);
			g.hidden = !anyVisible;
		});
		if (this.empty) this.empty.hidden = visibleCount > 0;
		setActive(this.el, visibleItems(this.el)[0]);
	},
	onInput() {
		this.filter(this.input.value);
	},
	onKey(e) {
		const all = visibleItems(this.el);
		const active = this.el.querySelector(
			'[data-slot="command-item"][data-active="true"]',
		);
		const idx = all.indexOf(active);

		if (e.key === "ArrowDown") {
			e.preventDefault();
			setActive(this.el, all[(idx + 1) % all.length] || all[0]);
		} else if (e.key === "ArrowUp") {
			e.preventDefault();
			setActive(
				this.el,
				all[(idx - 1 + all.length) % all.length] || all[all.length - 1],
			);
		} else if (e.key === "Enter") {
			e.preventDefault();
			if (active) this.dispatchSelect(active);
		} else if (e.key === "Home") {
			e.preventDefault();
			setActive(this.el, all[0]);
		} else if (e.key === "End") {
			e.preventDefault();
			setActive(this.el, all[all.length - 1]);
		}

		const currentActive = this.el.querySelector(
			'[data-slot="command-item"][data-active="true"]',
		);
		currentActive?.scrollIntoView({ block: "nearest" });
	},
	onClick(e) {
		const item = e.target.closest('[data-slot="command-item"]');
		if (!item || item.hasAttribute("data-disabled")) return;
		this.dispatchSelect(item);
	},
	onPointerOver(e) {
		const item = e.target.closest(
			'[data-slot="command-item"]:not([data-disabled])',
		);
		if (!item || item.hidden) return;
		setActive(this.el, item);
	},
	dispatchSelect(item) {
		const value = item.getAttribute("data-value");
		this.el.dispatchEvent(
			new CustomEvent("command:select", { detail: { value }, bubbles: true }),
		);
	},
};
