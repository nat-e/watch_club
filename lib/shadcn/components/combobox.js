// Hook for the <.combobox> component (lib/watch_club_web/components/ui/combobox.ex).
//
// Drives the input + popup pair: filter-as-you-type, keyboard nav,
// single/multi select, chip rendering for multi-select, clear button,
// click-outside dismissal. Mirrors Base UI's Combobox behavior.

import { position } from "./_position";

const ITEM_SEL = '[data-slot="combobox-item"]';
const ENABLED_ITEM_SEL = `${ITEM_SEL}:not([data-disabled])`;

function readJSON(el, attr, fallback) {
	const raw = el.getAttribute(attr);
	if (!raw) return fallback;
	try {
		return JSON.parse(raw);
	} catch {
		return fallback;
	}
}

function setup() {
	this.multiple = this.el.hasAttribute("data-multiple");
	this.autoHighlight = this.el.hasAttribute("data-auto-highlight");
	this.values = readJSON(this.el, "data-initial-value", []);

	this.content = this.el.querySelector('[data-slot="combobox-content"]');

	// Two input modes: typeable input (default) or button trigger + input inside popup.
	this.inputWrap = this.el.querySelector(
		':scope > [data-slot="combobox-input"]',
	);
	this.chipsWrap = this.el.querySelector(
		':scope > [data-slot="combobox-chips"]',
	);
	this.triggerButton = this.el.querySelector(
		':scope > [data-slot="combobox-trigger-button"]',
	);

	if (this.chipsWrap) {
		this.searchInput = this.chipsWrap.querySelector(
			'[data-slot="combobox-chips-input"]',
		);
		this.chipsList = this.chipsWrap.querySelector(
			'[data-slot="combobox-chips-list"]',
		);
		this.chipTemplate = this.el.querySelector(
			'[data-slot="combobox-chip-template"]',
		);
		this.anchor = this.chipsWrap;
	} else if (this.triggerButton) {
		this.searchInput = this.content.querySelector("input.input-group-control");
		this.valueDisplay = this.triggerButton.querySelector(
			'[data-slot="combobox-value"]',
		);
		this.anchor = this.triggerButton;
	} else if (this.inputWrap) {
		this.searchInput = this.inputWrap.querySelector(
			"input.input-group-control",
		);
		this.anchor = this.inputWrap;
	}

	this.popoverTrigger = this.inputWrap?.querySelector(
		".combobox-trigger-toggle",
	);
	this.clearButton = this.el.querySelector(".combobox-clear-button");

	this.empty = this.content.querySelector('[data-slot="combobox-empty"]');

	// Portal content to body so transformed/clipped ancestors don't trap it.
	if (this.content.parentElement !== document.body) {
		document.body.appendChild(this.content);
	}

	this.searchInput?.addEventListener("focus", this.onSearchFocus);
	this.searchInput?.addEventListener("input", this.onSearchInput);
	this.searchInput?.addEventListener("keydown", this.onSearchKey);
	this.popoverTrigger?.addEventListener("click", this.onTriggerToggle);
	this.triggerButton?.addEventListener("click", this.onTriggerToggle);
	this.clearButton?.addEventListener("click", this.onClearClick);
	this.content.addEventListener("click", this.onContentClick);
	this.content.addEventListener("pointerover", this.onPointerOver);
	this.chipsWrap?.addEventListener("click", this.onChipsClick);
	this.el.addEventListener("focusout", this.onFocusOut);

	// ARIA wiring for the listbox + input.
	if (this.searchInput) {
		this.searchInput.setAttribute("role", "combobox");
		this.searchInput.setAttribute("aria-autocomplete", "list");
		this.searchInput.setAttribute("aria-expanded", "false");
		this.searchInput.setAttribute("aria-controls", `${this.el.id}-list`);
	}
	const list = this.content.querySelector('[data-slot="combobox-list"]');
	if (list) list.id = `${this.el.id}-list`;

	this.syncSelected();
	this.renderValue();
	this.refreshClear();
	this.applyFilter("");
}

function teardown() {
	this.searchInput?.removeEventListener("focus", this.onSearchFocus);
	this.searchInput?.removeEventListener("input", this.onSearchInput);
	this.searchInput?.removeEventListener("keydown", this.onSearchKey);
	this.popoverTrigger?.removeEventListener("click", this.onTriggerToggle);
	this.triggerButton?.removeEventListener("click", this.onTriggerToggle);
	this.clearButton?.removeEventListener("click", this.onClearClick);
	this.content?.removeEventListener("click", this.onContentClick);
	this.content?.removeEventListener("pointerover", this.onPointerOver);
	this.chipsWrap?.removeEventListener("click", this.onChipsClick);
	this.el?.removeEventListener("focusout", this.onFocusOut);
	document.removeEventListener("pointerdown", this.onDocPointerDown, true);
	window.removeEventListener("resize", this.reposition);
	window.removeEventListener("scroll", this.reposition, true);
	this.content?.remove();
}

function items(content) {
	return Array.from(content.querySelectorAll(ENABLED_ITEM_SEL));
}

function visibleItems(content) {
	return items(content).filter((i) => !i.hidden);
}

function itemLabel(item) {
	return item.getAttribute("data-label") ?? item.textContent.trim();
}

function setHighlight(content, item) {
	content.querySelectorAll(ITEM_SEL).forEach((i) => {
		i.removeAttribute("data-highlighted");
	});
	if (item) {
		item.setAttribute("data-highlighted", "true");
		item.scrollIntoView({ block: "nearest" });
	}
}

export const ComboboxHook = {
	mounted() {
		this.onSearchFocus = this.onSearchFocus.bind(this);
		this.onSearchInput = this.onSearchInput.bind(this);
		this.onSearchKey = this.onSearchKey.bind(this);
		this.onTriggerToggle = this.onTriggerToggle.bind(this);
		this.onClearClick = this.onClearClick.bind(this);
		this.onContentClick = this.onContentClick.bind(this);
		this.onPointerOver = this.onPointerOver.bind(this);
		this.onChipsClick = this.onChipsClick.bind(this);
		this.onFocusOut = this.onFocusOut.bind(this);
		this.onDocPointerDown = this.onDocPointerDown.bind(this);
		this.reposition = this.reposition.bind(this);
		setup.call(this);
	},
	updated() {
		teardown.call(this);
		setup.call(this);
	},
	destroyed() {
		teardown.call(this);
	},
	isOpen() {
		return this.el.getAttribute("data-state") === "open";
	},
	isDisabled() {
		return this.el.hasAttribute("data-disabled");
	},
	open() {
		if (this.isOpen() || this.isDisabled()) return;
		this.el.setAttribute("data-state", "open");
		this.content.setAttribute("data-state", "open");
		this.searchInput?.setAttribute("aria-expanded", "true");
		this.reposition();
		document.addEventListener("pointerdown", this.onDocPointerDown, true);
		window.addEventListener("resize", this.reposition);
		window.addEventListener("scroll", this.reposition, true);
		if (this.autoHighlight) {
			setHighlight(this.content, visibleItems(this.content)[0]);
		}
	},
	close({ commitText = true } = {}) {
		if (!this.isOpen()) return;
		this.el.setAttribute("data-state", "closed");
		this.content.setAttribute("data-state", "closed");
		this.searchInput?.setAttribute("aria-expanded", "false");
		document.removeEventListener("pointerdown", this.onDocPointerDown, true);
		window.removeEventListener("resize", this.reposition);
		window.removeEventListener("scroll", this.reposition, true);
		setHighlight(this.content, null);
		if (commitText) this.renderValue();
		this.applyFilter("");
	},
	reposition() {
		position(this.content, this.anchor, {
			side: this.content.dataset.side || "bottom",
			align: this.content.dataset.align || "start",
			sideOffset: parseInt(this.content.dataset.sideOffset, 10) || 6,
			alignOffset: parseInt(this.content.dataset.alignOffset, 10) || 0,
		});
	},
	applyFilter(query) {
		const q = query.trim().toLowerCase();
		let visible = 0;
		items(this.content).forEach((item) => {
			const value = (item.getAttribute("data-value") || "").toLowerCase();
			const text = itemLabel(item).toLowerCase();
			const match = !q || value.includes(q) || text.includes(q);
			item.hidden = !match;
			if (match) visible++;
		});
		this.content
			.querySelectorAll('[data-slot="combobox-group"]')
			.forEach((g) => {
				const anyVisible = !!g.querySelector(`${ITEM_SEL}:not([hidden])`);
				g.hidden = !anyVisible;
			});
		if (this.empty) this.empty.hidden = visible > 0;
		if (this.autoHighlight && this.isOpen()) {
			setHighlight(this.content, visibleItems(this.content)[0]);
		}
	},
	syncSelected() {
		items(this.content).forEach((item) => {
			const value = item.getAttribute("data-value");
			const selected = this.values.includes(value);
			item.setAttribute("aria-selected", selected ? "true" : "false");
		});
	},
	renderValue() {
		if (this.chipsWrap) {
			this.renderChips();
		} else if (this.triggerButton && this.valueDisplay) {
			const placeholder = this.valueDisplay.getAttribute(
				"data-placeholder-text",
			);
			const label = this.valueLabels()[0];
			if (label) {
				this.valueDisplay.textContent = label;
				this.triggerButton.removeAttribute("data-placeholder");
			} else {
				this.valueDisplay.textContent = placeholder ?? "";
				this.triggerButton.setAttribute("data-placeholder", "true");
			}
		} else if (this.searchInput && !this.multiple) {
			this.searchInput.value = this.valueLabels()[0] || "";
		}
	},
	valueLabels() {
		return this.values.map((v) => {
			const item = this.content.querySelector(
				`${ITEM_SEL}[data-value="${CSS.escape(v)}"]`,
			);
			return item ? itemLabel(item) : v;
		});
	},
	refreshClear() {
		if (!this.clearButton) return;
		const hasValue = this.values.length > 0;
		this.clearButton.hidden = !hasValue;
		if (this.popoverTrigger) {
			this.popoverTrigger.hidden = hasValue;
		}
	},
	renderChips() {
		if (!this.chipsList || !this.chipTemplate) return;
		this.chipsList.innerHTML = "";
		const showRemove = this.chipTemplate.hasAttribute("data-show-remove");
		const labels = this.valueLabels();
		this.values.forEach((value, idx) => {
			const node = this.chipTemplate.content.firstElementChild.cloneNode(true);
			node.setAttribute("data-value", value);
			const label = node.querySelector('[data-slot="combobox-chip-label"]');
			if (label) label.textContent = labels[idx];
			const remove = node.querySelector('[data-slot="combobox-chip-remove"]');
			if (remove && !showRemove) remove.remove();
			this.chipsList.appendChild(node);
		});
	},
	syncFormInputs() {
		const name = this.el.querySelector(
			"[data-slot='combobox-form-input']",
		)?.name;
		if (!name) return;
		this.el
			.querySelectorAll('[data-slot="combobox-form-input"]')
			.forEach((n) => {
				n.remove();
			});
		const cleanName = this.multiple ? name : name;
		if (this.multiple) {
			this.values.forEach((v) => {
				const i = document.createElement("input");
				i.type = "hidden";
				i.name = cleanName;
				i.value = v;
				i.setAttribute("data-slot", "combobox-form-input");
				this.el.prepend(i);
			});
		} else {
			const i = document.createElement("input");
			i.type = "hidden";
			i.name = cleanName;
			i.value = this.values[0] || "";
			i.setAttribute("data-slot", "combobox-form-input");
			this.el.prepend(i);
		}
	},
	selectItem(item) {
		const value = item.getAttribute("data-value");
		if (this.multiple) {
			const idx = this.values.indexOf(value);
			if (idx >= 0) this.values.splice(idx, 1);
			else this.values.push(value);
			if (this.searchInput) this.searchInput.value = "";
			this.applyFilter("");
			this.searchInput?.focus();
		} else {
			this.values = [value];
		}
		this.syncSelected();
		this.refreshClear();
		this.renderValue();
		this.syncFormInputs();
		this.dispatchChange();
		if (!this.multiple) this.close();
	},
	removeChip(value) {
		const idx = this.values.indexOf(value);
		if (idx < 0) return;
		this.values.splice(idx, 1);
		this.syncSelected();
		this.refreshClear();
		this.renderValue();
		this.syncFormInputs();
		this.dispatchChange();
	},
	clearAll() {
		if (this.values.length === 0) return;
		this.values = [];
		if (this.searchInput) this.searchInput.value = "";
		this.applyFilter("");
		this.syncSelected();
		this.refreshClear();
		this.renderValue();
		this.syncFormInputs();
		this.dispatchChange();
	},
	dispatchChange() {
		this.el.dispatchEvent(
			new CustomEvent("combobox:change", {
				detail: {
					value: this.multiple ? [...this.values] : this.values[0] || "",
				},
				bubbles: true,
			}),
		);
	},
	onSearchFocus() {
		if (!this.isOpen()) this.open();
	},
	onSearchInput() {
		if (!this.isOpen()) this.open();
		this.applyFilter(this.searchInput.value);
	},
	onSearchKey(e) {
		const all = visibleItems(this.content);
		const active = this.content.querySelector(
			`${ITEM_SEL}[data-highlighted="true"]`,
		);
		const idx = all.indexOf(active);

		if (e.key === "ArrowDown") {
			e.preventDefault();
			if (!this.isOpen()) {
				this.open();
				return;
			}
			setHighlight(this.content, all[(idx + 1) % all.length] || all[0]);
		} else if (e.key === "ArrowUp") {
			e.preventDefault();
			if (!this.isOpen()) {
				this.open();
				return;
			}
			setHighlight(
				this.content,
				all[(idx - 1 + all.length) % all.length] || all[all.length - 1],
			);
		} else if (e.key === "Home") {
			if (this.isOpen()) {
				e.preventDefault();
				setHighlight(this.content, all[0]);
			}
		} else if (e.key === "End") {
			if (this.isOpen()) {
				e.preventDefault();
				setHighlight(this.content, all[all.length - 1]);
			}
		} else if (e.key === "Enter") {
			if (this.isOpen() && active) {
				e.preventDefault();
				this.selectItem(active);
			}
		} else if (e.key === "Escape") {
			if (this.isOpen()) {
				e.preventDefault();
				this.close();
			}
		} else if (
			e.key === "Backspace" &&
			this.multiple &&
			this.searchInput.value === ""
		) {
			const last = this.values[this.values.length - 1];
			if (last !== undefined) this.removeChip(last);
		}
	},
	onTriggerToggle(e) {
		e.preventDefault();
		if (this.isDisabled()) return;
		if (this.isOpen()) this.close();
		else {
			this.open();
			this.searchInput?.focus();
		}
	},
	onClearClick(e) {
		e.preventDefault();
		e.stopPropagation();
		this.clearAll();
		this.searchInput?.focus();
	},
	onContentClick(e) {
		const item = e.target.closest(ITEM_SEL);
		if (!item || item.hasAttribute("data-disabled")) return;
		this.selectItem(item);
	},
	onPointerOver(e) {
		const item = e.target.closest(ENABLED_ITEM_SEL);
		if (!item || item.hidden) return;
		setHighlight(this.content, item);
	},
	onChipsClick(e) {
		const remove = e.target.closest('[data-slot="combobox-chip-remove"]');
		if (remove) {
			e.preventDefault();
			e.stopPropagation();
			const chip = remove.closest('[data-slot="combobox-chip"]');
			if (chip) this.removeChip(chip.getAttribute("data-value"));
			this.searchInput?.focus();
			return;
		}
		if (e.target === this.chipsWrap) this.searchInput?.focus();
	},
	onFocusOut(e) {
		// Ignore focus shifts inside our root or into the portaled content.
		const next = e.relatedTarget;
		if (!next) return;
		if (this.el.contains(next) || this.content.contains(next)) return;
		this.close();
	},
	onDocPointerDown(e) {
		if (!this.isOpen()) return;
		if (this.el.contains(e.target)) return;
		if (this.content.contains(e.target)) return;
		this.close();
	},
};
