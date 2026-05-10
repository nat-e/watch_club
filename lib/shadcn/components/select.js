// Hook for the <.select> component (lib/watch_club_web/components/ui/select.ex).
// Same shape as `dropdown_menu.js`'s root hook (refreshRefs across morphs,
// content portaled to <body>), with listbox semantics: arrow nav, click /
// pointer-over to focus, Enter/Space to select. The trigger's displayed
// text is hydrated from the matching item's `[data-slot="select-item-text"]`.

import { position } from "./_position";

const ITEM_SELECTOR = '[data-slot="select-item"]:not([data-disabled])';
const ALL_ITEMS_SELECTOR = '[data-slot="select-item"]';

function items(content) {
	return Array.from(content.querySelectorAll(ITEM_SELECTOR));
}

export const SelectHook = {
	mounted() {
		this.onTriggerClick = this.onTriggerClick.bind(this);
		this.onTriggerKey = this.onTriggerKey.bind(this);
		this.onContentClick = this.onContentClick.bind(this);
		this.onContentKey = this.onContentKey.bind(this);
		this.onContentPointerOver = this.onContentPointerOver.bind(this);
		this.onDocPointerDown = this.onDocPointerDown.bind(this);
		this.onWindowResize = this.onWindowResize.bind(this);

		this.refreshRefs();
		this.syncDisplay();
	},

	// Re-find children and (re)bind listeners. LiveView morphs may replace
	// child elements when attrs change (e.g. Storybook playground swapping
	// size/disabled), leaving stale references. Rebind from scratch each
	// refresh, mirroring DropdownMenuHook.
	//
	// Also portal the content to <body>: any ancestor with a transform,
	// filter, backdrop-filter, perspective, will-change, contain, or
	// container-type creates a new containing block for `position: fixed`
	// descendants — anchoring the listbox to that ancestor instead of the
	// viewport. After a morph, morphdom may pull the content back to its
	// original location by id; we move it out again here.
	refreshRefs() {
		const newInput = this.el.querySelector(
			':scope > [data-slot="select-input"]',
		);
		const newTrigger = this.el.querySelector(
			':scope > [data-slot="select-trigger"]',
		);
		const newContent = document.getElementById(`${this.el.id}-content`);
		if (newContent && newContent.parentElement !== document.body) {
			document.body.appendChild(newContent);
		}

		if (this.trigger && this.trigger !== newTrigger) {
			this.trigger.removeEventListener("click", this.onTriggerClick);
			this.trigger.removeEventListener("keydown", this.onTriggerKey);
		}
		if (this.content && this.content !== newContent) {
			this.content.removeEventListener("click", this.onContentClick);
			this.content.removeEventListener("keydown", this.onContentKey);
			this.content.removeEventListener(
				"pointerover",
				this.onContentPointerOver,
			);
		}

		if (this.trigger !== newTrigger) {
			newTrigger.addEventListener("click", this.onTriggerClick);
			newTrigger.addEventListener("keydown", this.onTriggerKey);
		}
		if (this.content !== newContent) {
			newContent.addEventListener("click", this.onContentClick);
			newContent.addEventListener("keydown", this.onContentKey);
			newContent.addEventListener("pointerover", this.onContentPointerOver);
		}

		this.input = newInput;
		this.trigger = newTrigger;
		this.content = newContent;

		this.trigger.setAttribute("aria-controls", this.content.id);
		this.trigger.setAttribute(
			"aria-expanded",
			this.isOpen() ? "true" : "false",
		);
	},

	updated() {
		this.refreshRefs();
		this.syncDisplay();
	},

	destroyed() {
		document.removeEventListener("pointerdown", this.onDocPointerDown, true);
		window.removeEventListener("resize", this.onWindowResize);
		window.removeEventListener("scroll", this.onWindowResize, true);
		// Clean up the portaled content from <body>.
		this.content?.remove();
	},

	isOpen() {
		return this.el.getAttribute("data-state") === "open";
	},

	// Mirror the input value into item state (`data-selected`, `aria-selected`)
	// and into the trigger's value span. Server renders the placeholder; here
	// we replace it with the selected item's `select-item-text` content when
	// a match exists.
	syncDisplay() {
		const value = this.input.value;
		const valueSpan = this.trigger.querySelector('[data-slot="select-value"]');
		const placeholder =
			this.trigger.getAttribute("data-placeholder-text") ?? "";

		let selected = null;
		this.content.querySelectorAll(ALL_ITEMS_SELECTOR).forEach((item) => {
			const isSelected = item.getAttribute("data-value") === value;
			if (isSelected) {
				item.setAttribute("data-selected", "true");
				item.setAttribute("aria-selected", "true");
				selected = item;
			} else {
				item.removeAttribute("data-selected");
				item.setAttribute("aria-selected", "false");
			}
		});

		if (selected) {
			const text = selected.querySelector('[data-slot="select-item-text"]');
			valueSpan.innerHTML = text ? text.innerHTML : selected.textContent;
			this.trigger.removeAttribute("data-placeholder");
		} else {
			valueSpan.textContent = placeholder;
			this.trigger.setAttribute("data-placeholder", "");
		}
	},

	open(focus = "selected") {
		if (this.isOpen()) return;
		if (this.trigger.disabled) return;

		position(this.content, this.trigger, {
			side: this.el.dataset.side,
			align: this.el.dataset.align,
			sideOffset: parseInt(this.el.dataset.sideOffset, 10),
			alignOffset: parseInt(this.el.dataset.alignOffset, 10),
		});

		this.el.setAttribute("data-state", "open");
		this.content.setAttribute("data-state", "open");
		this.trigger.setAttribute("aria-expanded", "true");

		document.addEventListener("pointerdown", this.onDocPointerDown, true);
		window.addEventListener("resize", this.onWindowResize);
		window.addEventListener("scroll", this.onWindowResize, true);

		const enabled = items(this.content);
		let target;
		if (focus === "selected") {
			target =
				this.content.querySelector(
					'[data-slot="select-item"][data-selected="true"]:not([data-disabled])',
				) || enabled[0];
		} else if (focus === "first") {
			target = enabled[0];
		} else if (focus === "last") {
			target = enabled[enabled.length - 1];
		}
		target?.focus();
	},

	close({ returnFocus = true } = {}) {
		if (!this.isOpen()) return;
		this.el.setAttribute("data-state", "closed");
		this.content.setAttribute("data-state", "closed");
		this.trigger.setAttribute("aria-expanded", "false");

		document.removeEventListener("pointerdown", this.onDocPointerDown, true);
		window.removeEventListener("resize", this.onWindowResize);
		window.removeEventListener("scroll", this.onWindowResize, true);

		if (returnFocus) this.trigger.focus();
	},

	selectValue(value) {
		if (this.input.value !== value) {
			this.input.value = value;
			this.input.dispatchEvent(new Event("input", { bubbles: true }));
			this.input.dispatchEvent(new Event("change", { bubbles: true }));
			this.syncDisplay();
		}
		this.close();
	},

	onTriggerClick(e) {
		e.preventDefault();
		if (this.isOpen()) this.close();
		else this.open();
	},

	onTriggerKey(e) {
		if (e.key === "ArrowDown" || e.key === "Enter" || e.key === " ") {
			e.preventDefault();
			this.open("selected");
		} else if (e.key === "ArrowUp") {
			e.preventDefault();
			this.open("last");
		}
	},

	onContentClick(e) {
		const item = e.target.closest('[data-slot="select-item"]');
		if (!item) return;
		if (item.hasAttribute("data-disabled")) {
			e.preventDefault();
			e.stopPropagation();
			return;
		}
		this.selectValue(item.getAttribute("data-value"));
	},

	onContentKey(e) {
		if (!this.isOpen()) return;
		if (e.key === "Escape" || e.key === "Tab") {
			e.preventDefault();
			this.close();
			return;
		}
		const enabled = items(this.content);
		if (enabled.length === 0) return;
		const idx = enabled.indexOf(document.activeElement);

		if (e.key === "ArrowDown") {
			e.preventDefault();
			enabled[idx === -1 ? 0 : (idx + 1) % enabled.length]?.focus();
		} else if (e.key === "ArrowUp") {
			e.preventDefault();
			enabled[
				idx === -1
					? enabled.length - 1
					: (idx - 1 + enabled.length) % enabled.length
			]?.focus();
		} else if (e.key === "Home") {
			e.preventDefault();
			enabled[0]?.focus();
		} else if (e.key === "End") {
			e.preventDefault();
			enabled[enabled.length - 1]?.focus();
		} else if (e.key === "Enter" || e.key === " ") {
			e.preventDefault();
			const item = document.activeElement;
			if (item?.matches(ITEM_SELECTOR)) {
				this.selectValue(item.getAttribute("data-value"));
			}
		}
	},

	onContentPointerOver(e) {
		if (!this.isOpen()) return;
		const item = e.target.closest(ITEM_SELECTOR);
		if (item && item !== document.activeElement) item.focus();
	},

	onDocPointerDown(e) {
		if (!this.isOpen()) return;
		if (this.el.contains(e.target)) return;
		if (this.content.contains(e.target)) return;
		this.close({ returnFocus: false });
	},

	onWindowResize() {
		if (!this.isOpen()) return;
		position(this.content, this.trigger, {
			side: this.el.dataset.side,
			align: this.el.dataset.align,
			sideOffset: parseInt(this.el.dataset.sideOffset, 10),
			alignOffset: parseInt(this.el.dataset.alignOffset, 10),
		});
	},
};
