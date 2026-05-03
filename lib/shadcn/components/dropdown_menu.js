// Hooks for the <.dropdown_menu> component family
// (lib/watch_club_web/components/ui/dropdown_menu.ex).
//
// We export two hooks:
//   - DropdownMenuHook attaches to the root <.dropdown_menu> and drives
//     the top-level open/close, positioning, focus, and keyboard nav.
//   - DropdownMenuSubHook attaches to each <.dropdown_menu_sub> and
//     drives submenu open/close. Submenus reuse the parent's content
//     keydown for arrow navigation; they only handle their own
//     trigger keys, ArrowLeft to close back, and pointer hover delays.
//
// Submenu trigger/content are rendered as descendants of the parent
// menu's content (no portaling), so click-outside / Escape on the root
// naturally tear down the whole tree.
//
// Both hooks are registered in assets/js/components.js.

const ITEM_SELECTOR =
	'[data-slot="dropdown-menu-item"]:not([data-disabled]),' +
	'[data-slot="dropdown-menu-checkbox-item"]:not([data-disabled]),' +
	'[data-slot="dropdown-menu-radio-item"]:not([data-disabled]),' +
	'[data-slot="dropdown-menu-sub-trigger"]:not([data-disabled])';

const MENU_SELECTOR =
	'[data-slot="dropdown-menu-content"],[data-slot="dropdown-menu-sub-content"]';

// Items belonging to a given content/sub-content (excluding nested submenus).
function getMenuItems(menu) {
	return Array.from(menu.querySelectorAll(ITEM_SELECTOR)).filter(
		(item) => item.closest(MENU_SELECTOR) === menu,
	);
}

// Force a sub wrapper and its trigger/content to the closed state. Called
// during cascade-close from a parent hook that doesn't own the sub's state.
// Clears the inline `display` set in positionContent so the CSS
// `data-[state=closed]:hidden` rule can take effect.
function closeSubmenu(sub) {
	sub.setAttribute("data-state", "closed");
	sub
		.querySelector(':scope > [data-slot="dropdown-menu-sub-trigger"]')
		?.setAttribute("data-state", "closed");
	const content = sub.querySelector(
		':scope > [data-slot="dropdown-menu-sub-content"]',
	);
	if (content) {
		content.setAttribute("data-state", "closed");
		content.style.removeProperty("display");
	}
}

function oppositeSide(side) {
	return { top: "bottom", bottom: "top", left: "right", right: "left" }[side];
}

function transformOrigin(side, align) {
	const v = side === "bottom" ? "top" : side === "top" ? "bottom" : null;
	const h = side === "right" ? "left" : side === "left" ? "right" : null;

	if (v) {
		const x = align === "start" ? "left" : align === "end" ? "right" : "center";
		return `${x} ${v}`;
	}
	// side is left/right
	const y = align === "start" ? "top" : align === "end" ? "bottom" : "center";
	return `${h} ${y}`;
}

// Position `content` (already display:block) relative to `anchor`.
// Flips side when the requested side doesn't fit, clamps to viewport,
// and writes CSS custom properties used by the upstream classes.
function positionContent(content, anchor, opts) {
	const sideOffset = opts.sideOffset ?? 4;
	const alignOffset = opts.alignOffset ?? 0;
	const align = opts.align ?? "start";
	let side = opts.side ?? "bottom";

	// Override the `data-[state=closed]:hidden` so we can measure intrinsic
	// size. Cleared again in close() so CSS can hide the element.
	content.style.display = "block";
	content.style.left = "0px";
	content.style.top = "0px";
	content.style.removeProperty(
		"--watch-club-dropdown-menu-content-available-height",
	);

	const a = anchor.getBoundingClientRect();
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

	// Clamp to viewport.
	x = Math.max(margin, Math.min(x, window.innerWidth - c.width - margin));
	y = Math.max(margin, Math.min(y, window.innerHeight - c.height - margin));

	content.style.left = `${x}px`;
	content.style.top = `${y}px`;
	content.setAttribute("data-side", side);
	content.setAttribute("data-align", align);
	content.style.setProperty(
		"--watch-club-dropdown-menu-trigger-width",
		`${a.width}px`,
	);
	content.style.setProperty(
		"--watch-club-dropdown-menu-content-transform-origin",
		transformOrigin(side, align),
	);

	// Available height (for max-height) when stacked vertically.
	if (side === "bottom" || side === "top") {
		const available =
			side === "bottom"
				? window.innerHeight - a.bottom - sideOffset - margin
				: a.top - sideOffset - margin;
		content.style.setProperty(
			"--watch-club-dropdown-menu-content-available-height",
			`${available}px`,
		);
	}
}

// Focusable button-like element inside a trigger wrapper.
function focusableInside(wrapper) {
	return (
		wrapper.querySelector("button,a,[role='button'],[tabindex]") || wrapper
	);
}

// Element to position the menu against. The trigger wrapper itself uses
// `display: contents`, so its bounding rect is 0×0. Use the first element
// child that has layout, falling back to the wrapper.
function anchorInside(wrapper) {
	for (const child of wrapper.children) {
		const r = child.getBoundingClientRect();
		if (r.width > 0 || r.height > 0) return child;
	}
	return wrapper.firstElementChild || wrapper;
}

// Shared keyboard nav for any open menu. Returns true if it handled the key.
function handleArrowNav(menu, e) {
	// Only handle when the focused element belongs to *this* menu —
	// not to a deeper open submenu rendered as a descendant.
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
			if (focused?.getAttribute("data-slot") === "dropdown-menu-sub-trigger") {
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

export const DropdownMenuHook = {
	mounted() {
		this.root = this.el;

		this.onTriggerClick = this.onTriggerClick.bind(this);
		this.onTriggerKey = this.onTriggerKey.bind(this);
		this.onContentKey = this.onContentKey.bind(this);
		this.onContentClick = this.onContentClick.bind(this);
		this.onContentPointerOver = this.onContentPointerOver.bind(this);
		this.onDocPointerDown = this.onDocPointerDown.bind(this);
		this.onWindowResize = this.onWindowResize.bind(this);

		this.refreshRefs();
	},

	// Re-find children and (re)bind listeners. LiveView morphs may replace
	// child elements when attrs change (e.g. playground switching `align`),
	// leaving stale references that report 0×0 rects and breaking
	// positioning. We rebind from scratch each refresh.
	//
	// Also: portal the content to <body>. Any ancestor with a transform,
	// filter, backdrop-filter, perspective, will-change, contain, or
	// container-type creates a new containing block for `position: fixed`
	// descendants — anchoring the menu to that ancestor instead of the
	// viewport. (Common offender: a parent card with `backdrop-blur`.)
	// Moving the content to <body> escapes any such ancestor. After a
	// LiveView morph, morphdom may move the content back to its original
	// location by id; we move it out again here.
	refreshRefs() {
		const newTriggerWrap = this.el.querySelector(
			':scope > [data-slot="dropdown-menu-trigger"]',
		);
		const newContent = document.getElementById(`${this.el.id}-content`);
		// Defer portaling to a microtask so descendant hooks (e.g.
		// DropdownMenuSubHook on nested submenus) get a chance to mount
		// while the content is still inside the LiveView tree. Once moved
		// to <body>, LV no longer instantiates hooks on those children.
		if (newContent && newContent.parentElement !== document.body) {
			queueMicrotask(() => {
				if (newContent.parentElement !== document.body) {
					document.body.appendChild(newContent);
				}
			});
		}
		const newTrigger = focusableInside(newTriggerWrap);

		if (this.triggerWrap && this.triggerWrap !== newTriggerWrap) {
			this.triggerWrap.removeEventListener("click", this.onTriggerClick);
			this.triggerWrap.removeEventListener("keydown", this.onTriggerKey);
		}
		if (this.content && this.content !== newContent) {
			this.content.removeEventListener("keydown", this.onContentKey);
			this.content.removeEventListener("click", this.onContentClick);
			this.content.removeEventListener(
				"pointerover",
				this.onContentPointerOver,
			);
		}

		if (this.triggerWrap !== newTriggerWrap) {
			newTriggerWrap.addEventListener("click", this.onTriggerClick);
			newTriggerWrap.addEventListener("keydown", this.onTriggerKey);
		}
		if (this.content !== newContent) {
			newContent.addEventListener("keydown", this.onContentKey);
			newContent.addEventListener("click", this.onContentClick);
			newContent.addEventListener("pointerover", this.onContentPointerOver);
		}

		this.triggerWrap = newTriggerWrap;
		this.content = newContent;
		this.trigger = newTrigger;
		this.anchor = anchorInside(newTriggerWrap);

		this.trigger.setAttribute("aria-haspopup", "menu");
		this.trigger.setAttribute(
			"aria-expanded",
			this.isOpen() ? "true" : "false",
		);
		this.trigger.setAttribute("aria-controls", this.content.id);
	},

	updated() {
		this.refreshRefs();
	},

	destroyed() {
		document.removeEventListener("pointerdown", this.onDocPointerDown, true);
		window.removeEventListener("resize", this.onWindowResize);
		window.removeEventListener("scroll", this.onWindowResize, true);
		// Clean up the portaled content from <body>.
		this.content?.remove();
	},

	isOpen() {
		return this.root.getAttribute("data-state") === "open";
	},

	open(focus = "first") {
		if (this.isOpen()) return;
		// Re-resolve the anchor at open time — its rect may have changed since
		// mount, and (for `display: contents` wrappers) the children may have
		// been reflowed.
		this.anchor = anchorInside(this.triggerWrap);
		// Position before flipping to data-state=open so the entry animation
		// runs from the correct location.
		positionContent(this.content, this.anchor, {
			side: this.root.dataset.side,
			align: this.root.dataset.align,
			sideOffset: parseInt(this.root.dataset.sideOffset, 10),
			alignOffset: parseInt(this.root.dataset.alignOffset, 10),
		});

		this.root.setAttribute("data-state", "open");
		this.content.setAttribute("data-state", "open");
		this.trigger.setAttribute("aria-expanded", "true");

		const items = getMenuItems(this.content);
		if (focus === "first") items[0]?.focus();
		else if (focus === "last") items[items.length - 1]?.focus();

		document.addEventListener("pointerdown", this.onDocPointerDown, true);
		window.addEventListener("resize", this.onWindowResize);
		window.addEventListener("scroll", this.onWindowResize, true);
	},

	onContentPointerOver(e) {
		if (!this.isOpen()) return;
		const item = e.target.closest(ITEM_SELECTOR);
		if (!item) return;
		if (!getMenuItems(this.content).includes(item)) return;
		if (item === document.activeElement) return;
		item.focus();
	},

	close({ returnFocus = true } = {}) {
		if (!this.isOpen()) return;
		this.root.setAttribute("data-state", "closed");
		this.content.setAttribute("data-state", "closed");
		this.content.style.removeProperty("display");
		this.trigger.setAttribute("aria-expanded", "false");

		document.removeEventListener("pointerdown", this.onDocPointerDown, true);
		window.removeEventListener("resize", this.onWindowResize);
		window.removeEventListener("scroll", this.onWindowResize, true);

		// Cascade close all nested submenus.
		this.content
			.querySelectorAll('[data-slot="dropdown-menu-sub"][data-state="open"]')
			.forEach(closeSubmenu);

		if (returnFocus) this.trigger.focus();
	},

	onTriggerClick(e) {
		e.preventDefault();
		if (this.isOpen()) this.close();
		else this.open();
	},

	onTriggerKey(e) {
		if (e.key === "ArrowDown" || e.key === "Enter" || e.key === " ") {
			e.preventDefault();
			this.open("first");
		} else if (e.key === "ArrowUp") {
			e.preventDefault();
			this.open("last");
		}
	},

	onContentKey(e) {
		if (!this.isOpen()) return;
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

	onContentClick(e) {
		console.log("Dropdown menu clicked");
		const item = e.target.closest(
			'[data-slot="dropdown-menu-item"],' +
				'[data-slot="dropdown-menu-checkbox-item"],' +
				'[data-slot="dropdown-menu-radio-item"]',
		);
		console.log(item);
		if (!item) return;
		if (item.hasAttribute("data-disabled")) {
			console.log("Stopping");
			e.preventDefault();
			e.stopPropagation();
			return;
		}
		this.close({ returnFocus: false });
	},

	onDocPointerDown(e) {
		if (!this.isOpen()) return;
		if (this.root.contains(e.target)) return;
		// Content is portaled to <body>, so clicks inside it aren't descendants
		// of root — exempt them explicitly.
		if (this.content.contains(e.target)) return;
		this.close({ returnFocus: false });
	},

	onWindowResize() {
		if (!this.isOpen()) return;
		positionContent(this.content, this.anchor, {
			side: this.root.dataset.side,
			align: this.root.dataset.align,
			sideOffset: parseInt(this.root.dataset.sideOffset, 10),
			alignOffset: parseInt(this.root.dataset.alignOffset, 10),
		});
	},
};

export const DropdownMenuSubHook = {
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
			':scope > [data-slot="dropdown-menu-sub-trigger"]',
		);
		const newContent = this.sub.querySelector(
			':scope > [data-slot="dropdown-menu-sub-content"]',
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
		this.content.style.removeProperty("display");

		// Cascade close to nested submenus.
		this.content
			.querySelectorAll('[data-slot="dropdown-menu-sub"][data-state="open"]')
			.forEach(closeSubmenu);

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
