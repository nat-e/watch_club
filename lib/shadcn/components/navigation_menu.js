// Hook for the <.navigation_menu> component
// (lib/watch_club_web/components/ui/navigation_menu.ex).
//
// Coordinates a horizontal list of items where each item may open a
// content panel on hover (after `delay_duration`). One item is open
// at a time. Hopping between siblings while one is open swaps
// instantly within `skip_delay_duration` of the last close.
//
// Two layout modes:
//
//   - viewport=true  : a single shared panel below the list (the
//                      "viewport"). Active content is moved into the
//                      viewport at runtime; the viewport's width and
//                      height animate to match the active content's
//                      intrinsic size via CSS variables. Content is
//                      measured *before* being inserted (while still
//                      in its <li>) so the measurement reflects the
//                      content's natural width — not whatever the
//                      currently-empty viewport was sized to.
//   - viewport=false : each item's content drops down inline, absolute
//                      below its trigger.

const ITEM_SELECTOR = '[data-slot="navigation-menu-item"]';
const TRIGGER_SELECTOR = '[data-slot="navigation-menu-trigger"]';
const CONTENT_SELECTOR = '[data-slot="navigation-menu-content"]';
const VIEWPORT_SELECTOR = '[data-slot="navigation-menu-viewport"]';
const LINK_SELECTOR = '[data-slot="navigation-menu-link"]';

const CLOSE_DELAY = 150;

function getItems(root) {
	return Array.from(root.querySelectorAll(`:scope > ul > ${ITEM_SELECTOR}`));
}

function getTrigger(item) {
	return item.querySelector(`:scope > ${TRIGGER_SELECTOR}`);
}

// Find the content for an item. After the content has been moved into
// the viewport, it is no longer a child of the <li>; in that case the
// caller should use the explicit `this.activeContent` reference.
function getContent(item) {
	return item.querySelector(`:scope > ${CONTENT_SELECTOR}`);
}

function getTriggers(root) {
	return getItems(root)
		.map((item) => getTrigger(item))
		.filter(Boolean);
}

export const NavigationMenuHook = {
	mounted() {
		this.openTimer = null;
		this.closeTimer = null;
		this.skipDelayTimer = null;
		this.isWithinSkipWindow = false;
		this.activeItem = null;
		this.activeContent = null;
		this.contentHomes = new WeakMap();

		this.onTriggerEnter = this.onTriggerEnter.bind(this);
		this.onTriggerLeave = this.onTriggerLeave.bind(this);
		this.onTriggerClick = this.onTriggerClick.bind(this);
		this.onTriggerKey = this.onTriggerKey.bind(this);
		this.onContentEnter = this.onContentEnter.bind(this);
		this.onContentLeave = this.onContentLeave.bind(this);
		this.onContentKey = this.onContentKey.bind(this);
		this.onViewportEnter = this.onViewportEnter.bind(this);
		this.onViewportLeave = this.onViewportLeave.bind(this);
		this.onDocPointerDown = this.onDocPointerDown.bind(this);
		this.onWindowResize = this.onWindowResize.bind(this);

		this.refresh();
	},

	updated() {
		this.refresh();
	},

	destroyed() {
		clearTimeout(this.openTimer);
		clearTimeout(this.closeTimer);
		clearTimeout(this.skipDelayTimer);
		document.removeEventListener("pointerdown", this.onDocPointerDown, true);
		window.removeEventListener("resize", this.onWindowResize);
		window.removeEventListener("scroll", this.onWindowResize, true);
		this.unbindAll();
	},

	refresh() {
		this.unbindAll();

		this.viewport = this.el.querySelector(VIEWPORT_SELECTOR);
		this.usesViewport = this.el.dataset.viewport === "true";
		this.delayDuration = parseInt(this.el.dataset.delayDuration, 10);
		this.skipDelayDuration = parseInt(this.el.dataset.skipDelayDuration, 10);

		if (this.viewport) {
			this.viewport.addEventListener("pointerenter", this.onViewportEnter);
			this.viewport.addEventListener("pointerleave", this.onViewportLeave);
		}

		this.items = getItems(this.el);
		this.items.forEach((item) => {
			const trigger = getTrigger(item);
			const content = getContent(item);
			if (trigger) {
				trigger.addEventListener("pointerenter", this.onTriggerEnter);
				trigger.addEventListener("pointerleave", this.onTriggerLeave);
				trigger.addEventListener("click", this.onTriggerClick);
				trigger.addEventListener("keydown", this.onTriggerKey);
			}
			if (content) {
				content.addEventListener("pointerenter", this.onContentEnter);
				content.addEventListener("pointerleave", this.onContentLeave);
				content.addEventListener("keydown", this.onContentKey);
				if (!this.contentHomes.has(content)) {
					this.contentHomes.set(content, item);
				}
			}
		});

		if (this.activeItem && !this.items.includes(this.activeItem)) {
			this.activeItem = null;
			this.activeContent = null;
			this.setRootState("closed");
		}
	},

	unbindAll() {
		this.viewport?.removeEventListener("pointerenter", this.onViewportEnter);
		this.viewport?.removeEventListener("pointerleave", this.onViewportLeave);
		this.items?.forEach((item) => {
			const trigger = getTrigger(item);
			const content = getContent(item);
			trigger?.removeEventListener("pointerenter", this.onTriggerEnter);
			trigger?.removeEventListener("pointerleave", this.onTriggerLeave);
			trigger?.removeEventListener("click", this.onTriggerClick);
			trigger?.removeEventListener("keydown", this.onTriggerKey);
			content?.removeEventListener("pointerenter", this.onContentEnter);
			content?.removeEventListener("pointerleave", this.onContentLeave);
			content?.removeEventListener("keydown", this.onContentKey);
		});
	},

	itemFromTrigger(target) {
		return target.closest(ITEM_SELECTOR);
	},

	itemFromContent(target) {
		const content = target.closest(CONTENT_SELECTOR);
		if (!content) return null;
		return this.contentHomes.get(content) || content.closest(ITEM_SELECTOR);
	},

	setRootState(state) {
		this.el.setAttribute("data-state", state);
	},

	setItemState(item, content, state) {
		item.setAttribute("data-state", state);
		const trigger = getTrigger(item);
		trigger?.setAttribute("data-state", state);
		trigger?.setAttribute("aria-expanded", state === "open" ? "true" : "false");
		content?.setAttribute("data-state", state);
	},

	// Read intrinsic size with the content briefly visible-but-invisible
	// outside its normal flow, so the parent's constraints don't affect
	// measurement.
	measureContent(content) {
		const homeAttrHidden = content.hidden;
		const orig = {
			position: content.style.position,
			visibility: content.style.visibility,
			display: content.style.display,
			width: content.style.width,
			height: content.style.height,
			top: content.style.top,
			left: content.style.left,
		};
		content.hidden = false;
		content.style.position = "absolute";
		content.style.visibility = "hidden";
		content.style.display = "block";
		content.style.top = "0px";
		content.style.left = "0px";
		content.style.width = "";
		content.style.height = "";
		const rect = content.getBoundingClientRect();
		Object.assign(content.style, orig);
		content.hidden = homeAttrHidden;
		return rect;
	},

	open(item) {
		if (!item) return;
		// If item's content is currently in the viewport, find it; else
		// use the in-li lookup.
		const content =
			item === this.activeItem ? this.activeContent : getContent(item);
		if (!content) return;

		clearTimeout(this.openTimer);
		clearTimeout(this.closeTimer);

		// Close any already-open item first so we have a consistent "one
		// open at a time" invariant before showing the new one.
		if (this.activeItem && this.activeItem !== item) {
			this.hideContent(this.activeItem, this.activeContent);
			this.setItemState(this.activeItem, this.activeContent, "closed");
		}

		if (this.usesViewport) {
			const rect = this.measureContent(content);
			this.viewport.style.setProperty(
				"--watch-club-navigation-menu-viewport-width",
				`${Math.ceil(rect.width)}px`,
			);
			this.viewport.style.setProperty(
				"--watch-club-navigation-menu-viewport-height",
				`${Math.ceil(rect.height)}px`,
			);

			const trigger = getTrigger(item);
			if (trigger) {
				const tRect = trigger.getBoundingClientRect();
				const navRect = this.el.getBoundingClientRect();
				this.viewport.style.setProperty(
					"--watch-club-navigation-menu-trigger-center",
					`${Math.round(tRect.left + tRect.width / 2 - navRect.left)}px`,
				);
			}

			content.hidden = false;
			if (content.parentElement !== this.viewport) {
				this.viewport.appendChild(content);
			}
		} else {
			content.hidden = false;
			this.positionInlineContent(item, content);
		}

		this.activeItem = item;
		this.activeContent = content;
		this.setRootState("open");
		this.setItemState(item, content, "open");
		if (this.viewport) this.viewport.setAttribute("data-state", "open");

		this.isWithinSkipWindow = false;
		clearTimeout(this.skipDelayTimer);

		document.addEventListener("pointerdown", this.onDocPointerDown, true);
		window.addEventListener("resize", this.onWindowResize);
		window.addEventListener("scroll", this.onWindowResize, true);
	},

	close({ immediate = false } = {}) {
		clearTimeout(this.openTimer);
		clearTimeout(this.closeTimer);
		if (!this.activeItem) return;

		const closingItem = this.activeItem;
		const closingContent = this.activeContent;
		this.activeItem = null;
		this.activeContent = null;
		this.setRootState("closed");
		this.setItemState(closingItem, closingContent, "closed");
		if (this.viewport) this.viewport.setAttribute("data-state", "closed");

		this.hideContent(closingItem, closingContent);

		document.removeEventListener("pointerdown", this.onDocPointerDown, true);
		window.removeEventListener("resize", this.onWindowResize);
		window.removeEventListener("scroll", this.onWindowResize, true);

		if (!immediate) {
			this.isWithinSkipWindow = true;
			clearTimeout(this.skipDelayTimer);
			this.skipDelayTimer = setTimeout(() => {
				this.isWithinSkipWindow = false;
			}, this.skipDelayDuration);
		} else {
			this.isWithinSkipWindow = false;
		}
	},

	hideContent(item, content) {
		if (!content) return;
		if (this.usesViewport) {
			// Return the content to its original <li> so subsequent opens
			// find it via getContent(item).
			const home = this.contentHomes.get(content) || item;
			if (content.parentElement !== home) {
				home.appendChild(content);
			}
		} else {
			content.style.left = "";
			content.style.top = "";
			content.style.position = "";
			content.style.width = "";
		}
		content.hidden = true;
	},

	positionInlineContent(item, content) {
		const trigger = getTrigger(item);
		if (!trigger) return;
		content.style.position = "absolute";
		content.style.top = "100%";
		content.style.left = "0";
	},

	onTriggerEnter(e) {
		const item = this.itemFromTrigger(e.target);
		if (!item) return;
		clearTimeout(this.closeTimer);
		if (this.activeItem === item) return;

		if (this.activeItem || this.isWithinSkipWindow) {
			this.open(item);
		} else {
			clearTimeout(this.openTimer);
			this.openTimer = setTimeout(() => this.open(item), this.delayDuration);
		}
	},

	onTriggerLeave(e) {
		clearTimeout(this.openTimer);
		const item = this.itemFromTrigger(e.target);
		if (!item) return;
		if (this.activeItem !== item) return;
		clearTimeout(this.closeTimer);
		this.closeTimer = setTimeout(() => this.close(), CLOSE_DELAY);
	},

	onTriggerClick(e) {
		e.preventDefault();
		const item = this.itemFromTrigger(e.target);
		if (!item) return;
		if (this.activeItem === item) {
			this.close({ immediate: true });
		} else {
			this.open(item);
		}
	},

	onTriggerKey(e) {
		const item = this.itemFromTrigger(e.target);
		if (!item) return;
		const triggers = getTriggers(this.el);
		const idx = triggers.indexOf(getTrigger(item));

		switch (e.key) {
			case "ArrowDown":
			case "Enter":
			case " ":
				e.preventDefault();
				this.open(item);
				requestAnimationFrame(() => {
					const content = this.activeContent;
					const firstLink = content?.querySelector(LINK_SELECTOR);
					firstLink?.focus();
				});
				break;
			case "Escape":
				e.preventDefault();
				if (this.activeItem === item) this.close({ immediate: true });
				break;
			case "ArrowRight":
				if (idx >= 0 && idx < triggers.length - 1) {
					e.preventDefault();
					triggers[idx + 1].focus();
				}
				break;
			case "ArrowLeft":
				if (idx > 0) {
					e.preventDefault();
					triggers[idx - 1].focus();
				}
				break;
		}
	},

	onContentEnter() {
		clearTimeout(this.closeTimer);
	},

	onContentLeave() {
		clearTimeout(this.closeTimer);
		this.closeTimer = setTimeout(() => this.close(), CLOSE_DELAY);
	},

	onContentKey(e) {
		if (e.key === "Escape") {
			e.preventDefault();
			const item = this.itemFromContent(e.target);
			const trigger = item ? getTrigger(item) : null;
			this.close({ immediate: true });
			trigger?.focus();
		}
	},

	onViewportEnter() {
		clearTimeout(this.closeTimer);
	},

	onViewportLeave() {
		clearTimeout(this.closeTimer);
		this.closeTimer = setTimeout(() => this.close(), CLOSE_DELAY);
	},

	onDocPointerDown(e) {
		if (!this.activeItem) return;
		if (this.el.contains(e.target)) return;
		if (this.viewport?.contains(e.target)) return;
		this.close({ immediate: true });
	},

	onWindowResize() {
		if (!this.activeItem || !this.activeContent) return;
		if (this.usesViewport) {
			// Re-measure (the layout context may have changed). The content
			// is currently inside the viewport, but since the viewport sizes
			// itself from these vars, measureContent's temporary
			// position:absolute escape will give us the natural size.
			const rect = this.measureContent(this.activeContent);
			this.viewport.style.setProperty(
				"--watch-club-navigation-menu-viewport-width",
				`${Math.ceil(rect.width)}px`,
			);
			this.viewport.style.setProperty(
				"--watch-club-navigation-menu-viewport-height",
				`${Math.ceil(rect.height)}px`,
			);
		}
	},
};
