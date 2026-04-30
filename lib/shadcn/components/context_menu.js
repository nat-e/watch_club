// Hooks for the <.context_menu> component family
// (lib/watch_club_web/components/ui/context_menu.ex).
//
// We export two hooks:
//   - ContextMenuHook attaches to the root <.context_menu> and drives
//     the top-level open/close, positioning at the cursor, focus, and
//     keyboard nav. Opens on `contextmenu` (right-click) of the trigger
//     region instead of below a button.
//   - ContextMenuSubHook attaches to each <.context_menu_sub> and
//     drives submenu open/close. Submenus reuse the parent's content
//     keydown for arrow navigation; they only handle their own
//     trigger keys, ArrowLeft to close back, and pointer hover delays.
//
// Submenu trigger/content are rendered as descendants of the root
// menu's content (which itself is portaled to <body>), so click-outside /
// Escape on the root naturally tear down the whole tree.
//
// Both hooks are registered in assets/js/components.js.

const ITEM_SELECTOR =
	'[data-slot="context-menu-item"]:not([data-disabled]),' +
	'[data-slot="context-menu-checkbox-item"]:not([data-disabled]),' +
	'[data-slot="context-menu-radio-item"]:not([data-disabled]),' +
	'[data-slot="context-menu-sub-trigger"]:not([data-disabled])';

const MENU_SELECTOR =
	'[data-slot="context-menu-content"],[data-slot="context-menu-sub-content"]';

// Items belonging to a given content/sub-content (excluding nested submenus).
function getMenuItems(menu) {
	return Array.from(menu.querySelectorAll(ITEM_SELECTOR)).filter(
		(item) => item.closest(MENU_SELECTOR) === menu,
	);
}

function oppositeSide(side) {
	return { top: "bottom", bottom: "top", left: "right", right: "left" }[side];
}

// Position `content` relative to `anchor` (a DOMRect or element).
// Flips side when the requested side doesn't fit, clamps to viewport,
// and writes CSS custom properties used by the upstream classes.
function positionContent(content, anchor, opts) {
	const sideOffset = opts.sideOffset ?? 4;
	const alignOffset = opts.alignOffset ?? 0;
	const align = opts.align ?? "start";
	let side = opts.side ?? "bottom";

	content.style.left = "0px";
	content.style.top = "0px";
	content.style.removeProperty(
		"--watch-club-context-menu-content-available-height",
	);

	const a = anchor instanceof Element ? anchor.getBoundingClientRect() : anchor;
	const c = content.getBoundingClientRect();
	const margin = 8;

	const room = {
		top: a.top - margin,
		bottom: window.innerHeight - a.bottom - margin,
		left: a.left - margin,
		right: window.innerWidth - a.right - margin,
	};

	const needed = side === "top" || side === "bottom" ? c.height : c.width;
	if (
		room[side] < needed + sideOffset &&
		room[oppositeSide(side)] > room[side]
	) {
		side = oppositeSide(side);
	}

	let x = 0;
	let y = 0;

	if (side === "bottom" || side === "top") {
		y =
			side === "bottom" ? a.bottom + sideOffset : a.top - c.height - sideOffset;
		if (align === "start") x = a.left + alignOffset;
		else if (align === "end") x = a.right - c.width + alignOffset;
		else x = a.left + a.width / 2 - c.width / 2 + alignOffset;
	} else {
		x = side === "right" ? a.right + sideOffset : a.left - c.width - sideOffset;
		if (align === "start") y = a.top + alignOffset;
		else if (align === "end") y = a.bottom - c.height + alignOffset;
		else y = a.top + a.height / 2 - c.height / 2 + alignOffset;
	}

	x = Math.max(margin, Math.min(x, window.innerWidth - c.width - margin));
	y = Math.max(margin, Math.min(y, window.innerHeight - c.height - margin));

	content.style.left = `${x}px`;
	content.style.top = `${y}px`;
	content.setAttribute("data-side", side);
	content.setAttribute("data-align", align);

	if (side === "bottom" || side === "top") {
		const available =
			side === "bottom"
				? window.innerHeight - a.bottom - sideOffset - margin
				: a.top - sideOffset - margin;
		content.style.setProperty(
			"--watch-club-context-menu-content-available-height",
			`${available}px`,
		);
	}
}

// Shared keyboard nav for any open menu. Returns true if it handled the key.
function handleArrowNav(menu, e) {
	const focused = document.activeElement;
	if (focused?.closest(MENU_SELECTOR) !== menu) return false;

	const items = getMenuItems(menu);
	if (items.length === 0) return false;
	const idx = items.indexOf(focused);

	switch (e.key) {
		case "ArrowDown":
			e.preventDefault();
			e.stopPropagation();
			items[idx === -1 ? 0 : (idx + 1) % items.length]?.focus();
			return true;
		case "ArrowUp":
			e.preventDefault();
			e.stopPropagation();
			items[
				idx === -1 ? items.length - 1 : (idx - 1 + items.length) % items.length
			]?.focus();
			return true;
		case "Home":
			e.preventDefault();
			e.stopPropagation();
			items[0]?.focus();
			return true;
		case "End":
			e.preventDefault();
			e.stopPropagation();
			items[items.length - 1]?.focus();
			return true;
		case "Enter":
		case " ":
			// Sub-triggers handle Enter/Space themselves to open the submenu.
			if (focused?.getAttribute("data-slot") === "context-menu-sub-trigger") {
				return false;
			}
			e.preventDefault();
			e.stopPropagation();
			focused?.click();
			return true;
		default:
			return false;
	}
}

function setup() {
	this.trigger = this.el.querySelector(
		':scope > [data-slot="context-menu-trigger"]',
	);
	this.content = document.getElementById(`${this.el.id}-content`);
	if (this.content.parentElement !== document.body) {
		document.body.appendChild(this.content);
	}

	this.trigger.addEventListener("contextmenu", this.onContextMenu);
	this.content.addEventListener("click", this.onContentClick);
	this.content.addEventListener("pointerover", this.onPointerOver);
	this.content.addEventListener("keydown", this.onKey);
}

function teardown() {
	this.trigger?.removeEventListener("contextmenu", this.onContextMenu);
	this.content?.removeEventListener("click", this.onContentClick);
	this.content?.removeEventListener("pointerover", this.onPointerOver);
	this.content?.removeEventListener("keydown", this.onKey);
	document.removeEventListener("pointerdown", this.onDocPointerDown, true);
	document.removeEventListener("scroll", this.onScroll, true);
	this.content?.remove();
}

export const ContextMenuHook = {
	mounted() {
		this.onContextMenu = this.onContextMenu.bind(this);
		this.onContentClick = this.onContentClick.bind(this);
		this.onPointerOver = this.onPointerOver.bind(this);
		this.onKey = this.onKey.bind(this);
		this.onDocPointerDown = this.onDocPointerDown.bind(this);
		this.onScroll = this.onScroll.bind(this);
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
	open(x, y) {
		// Anchor the menu at a 1×1 rect at the cursor: positionContent then
		// handles flipping/clamping and writes the same CSS vars used by the
		// upstream styles.
		const anchor = {
			left: x,
			top: y,
			right: x,
			bottom: y,
			width: 0,
			height: 0,
		};
		positionContent(this.content, anchor, {
			side: "bottom",
			align: "start",
			sideOffset: 0,
			alignOffset: 0,
		});

		this.el.setAttribute("data-state", "open");
		this.content.setAttribute("data-state", "open");
		getMenuItems(this.content)[0]?.focus();
		document.addEventListener("pointerdown", this.onDocPointerDown, true);
		document.addEventListener("scroll", this.onScroll, true);
	},
	close() {
		if (!this.isOpen()) return;
		this.el.setAttribute("data-state", "closed");
		this.content.setAttribute("data-state", "closed");
		document.removeEventListener("pointerdown", this.onDocPointerDown, true);
		document.removeEventListener("scroll", this.onScroll, true);

		// Cascade close all nested submenus.
		this.content
			.querySelectorAll('[data-slot="context-menu-sub"][data-state="open"]')
			.forEach((sub) => {
				sub.setAttribute("data-state", "closed");
				sub
					.querySelector(':scope > [data-slot="context-menu-sub-trigger"]')
					?.setAttribute("data-state", "closed");
				sub
					.querySelector(':scope > [data-slot="context-menu-sub-content"]')
					?.setAttribute("data-state", "closed");
			});
	},
	onContextMenu(e) {
		e.preventDefault();
		this.open(e.clientX, e.clientY);
	},
	onContentClick(e) {
		const item = e.target.closest(
			'[data-slot="context-menu-item"],' +
				'[data-slot="context-menu-checkbox-item"],' +
				'[data-slot="context-menu-radio-item"]',
		);
		if (!item) return;
		if (item.hasAttribute("data-disabled")) {
			e.preventDefault();
			e.stopPropagation();
			return;
		}
		this.close();
	},
	onPointerOver(e) {
		if (!this.isOpen()) return;
		const item = e.target.closest(ITEM_SELECTOR);
		if (!item) return;
		if (!getMenuItems(this.content).includes(item)) return;
		if (item === document.activeElement) return;
		item.focus();
	},
	onKey(e) {
		if (e.key === "Escape") {
			e.preventDefault();
			this.close();
			return;
		}
		if (e.key === "Tab") {
			e.preventDefault();
			this.close();
			return;
		}
		handleArrowNav(this.content, e);
	},
	onDocPointerDown(e) {
		if (!this.isOpen()) return;
		if (this.content.contains(e.target)) return;
		this.close();
	},
	onScroll() {
		this.close();
	},
};

export const ContextMenuSubHook = {
	mounted() {
		this.sub = this.el;
		this.openTimer = null;
		this.closeTimer = null;

		this.onTriggerClick = this.onTriggerClick.bind(this);
		this.onTriggerKey = this.onTriggerKey.bind(this);
		this.onTriggerEnter = this.onTriggerEnter.bind(this);
		this.onTriggerLeave = this.onTriggerLeave.bind(this);
		this.onContentEnter = this.onContentEnter.bind(this);
		this.onContentLeave = this.onContentLeave.bind(this);
		this.onContentKey = this.onContentKey.bind(this);
		this.onContentPointerOver = this.onContentPointerOver.bind(this);

		this.refreshRefs();
	},

	refreshRefs() {
		const newTrigger = this.sub.querySelector(
			':scope > [data-slot="context-menu-sub-trigger"]',
		);
		const newContent = this.sub.querySelector(
			':scope > [data-slot="context-menu-sub-content"]',
		);

		if (this.trigger && this.trigger !== newTrigger) {
			this.trigger.removeEventListener("click", this.onTriggerClick);
			this.trigger.removeEventListener("keydown", this.onTriggerKey);
			this.trigger.removeEventListener("pointerenter", this.onTriggerEnter);
			this.trigger.removeEventListener("pointerleave", this.onTriggerLeave);
		}
		if (this.content && this.content !== newContent) {
			this.content.removeEventListener("pointerenter", this.onContentEnter);
			this.content.removeEventListener("pointerleave", this.onContentLeave);
			this.content.removeEventListener("keydown", this.onContentKey);
			this.content.removeEventListener(
				"pointerover",
				this.onContentPointerOver,
			);
		}

		if (this.trigger !== newTrigger) {
			newTrigger.addEventListener("click", this.onTriggerClick);
			newTrigger.addEventListener("keydown", this.onTriggerKey);
			newTrigger.addEventListener("pointerenter", this.onTriggerEnter);
			newTrigger.addEventListener("pointerleave", this.onTriggerLeave);
		}
		if (this.content !== newContent) {
			newContent.addEventListener("pointerenter", this.onContentEnter);
			newContent.addEventListener("pointerleave", this.onContentLeave);
			newContent.addEventListener("keydown", this.onContentKey);
			newContent.addEventListener("pointerover", this.onContentPointerOver);
		}

		this.trigger = newTrigger;
		this.content = newContent;
	},

	updated() {
		this.refreshRefs();
	},

	destroyed() {
		clearTimeout(this.openTimer);
		clearTimeout(this.closeTimer);
	},

	isOpen() {
		return this.sub.getAttribute("data-state") === "open";
	},

	open({ focusFirst = false } = {}) {
		clearTimeout(this.closeTimer);
		if (this.isOpen()) return;
		if (this.trigger.hasAttribute("data-disabled")) return;

		positionContent(this.content, this.trigger, {
			side: "right",
			align: "start",
			sideOffset: 4,
			alignOffset: -4,
		});

		this.sub.setAttribute("data-state", "open");
		this.trigger.setAttribute("data-state", "open");
		this.trigger.setAttribute("aria-expanded", "true");
		this.content.setAttribute("data-state", "open");

		if (focusFirst) {
			const items = getMenuItems(this.content);
			items[0]?.focus();
		}
	},

	close({ returnFocus = false } = {}) {
		clearTimeout(this.openTimer);
		if (!this.isOpen()) return;
		this.sub.setAttribute("data-state", "closed");
		this.trigger.setAttribute("data-state", "closed");
		this.trigger.setAttribute("aria-expanded", "false");
		this.content.setAttribute("data-state", "closed");

		this.content
			.querySelectorAll('[data-slot="context-menu-sub"][data-state="open"]')
			.forEach((sub) => {
				sub.setAttribute("data-state", "closed");
				sub
					.querySelector(':scope > [data-slot="context-menu-sub-trigger"]')
					?.setAttribute("data-state", "closed");
				sub
					.querySelector(':scope > [data-slot="context-menu-sub-content"]')
					?.setAttribute("data-state", "closed");
			});

		if (returnFocus) this.trigger.focus();
	},

	onTriggerClick(e) {
		e.preventDefault();
		e.stopPropagation();
		if (this.isOpen()) this.close({ returnFocus: true });
		else this.open({ focusFirst: true });
	},

	onTriggerKey(e) {
		if (document.activeElement !== this.trigger) return;
		if (e.key === "ArrowRight" || e.key === "Enter" || e.key === " ") {
			e.preventDefault();
			e.stopPropagation();
			this.open({ focusFirst: true });
		}
	},

	onTriggerEnter() {
		clearTimeout(this.closeTimer);
		this.openTimer = setTimeout(() => this.open(), 100);
	},

	onTriggerLeave() {
		clearTimeout(this.openTimer);
		this.closeTimer = setTimeout(() => this.close(), 300);
	},

	onContentEnter() {
		clearTimeout(this.closeTimer);
	},

	onContentLeave() {
		this.closeTimer = setTimeout(() => this.close(), 300);
	},

	onContentKey(e) {
		const focused = document.activeElement;
		if (focused?.closest(MENU_SELECTOR) !== this.content) return;
		if (e.key === "ArrowLeft") {
			e.preventDefault();
			e.stopPropagation();
			this.close({ returnFocus: true });
			return;
		}
		handleArrowNav(this.content, e);
	},

	onContentPointerOver(e) {
		if (!this.isOpen()) return;
		const item = e.target.closest(ITEM_SELECTOR);
		if (!item) return;
		if (!getMenuItems(this.content).includes(item)) return;
		if (item === document.activeElement) return;
		item.focus();
	},
};
