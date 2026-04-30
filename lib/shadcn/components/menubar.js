// Hook for the <.menubar> component (lib/watch_club_web/components/ui/menubar.ex).
//
// Coordinates ArrowLeft/ArrowRight navigation across sibling menus inside
// a menubar. When a menu is open and the user presses Left/Right, we close
// the current one and open its previous/next sibling. When focus is on a
// trigger but no menu is open, we just move focus across triggers.
//
// Each menu is a `<.dropdown_menu>` and owns its own portaled content. The
// hook locates the menus, their triggers, and their contents (which may be
// portaled to <body>) and binds keydown listeners on both ends.

function getMenus(root) {
	return Array.from(
		root.querySelectorAll(':scope > [data-slot="dropdown-menu"]'),
	);
}

function getMenuParts(menu) {
	const trigger = menu.querySelector(
		':scope > [data-slot="dropdown-menu-trigger"] [data-slot="menubar-trigger"]',
	);
	const content = document.getElementById(`${menu.id}-content`);
	return { trigger, content };
}

function focusableInside(wrapper) {
	return wrapper?.querySelector("button,[tabindex]") || wrapper;
}

export const MenubarHook = {
	mounted() {
		this.onKey = this.onKey.bind(this);
		this.bindListeners();
	},

	updated() {
		this.unbindListeners();
		this.bindListeners();
	},

	destroyed() {
		this.unbindListeners();
	},

	bindListeners() {
		this.parts = getMenus(this.el).map((menu) => {
			const { trigger, content } = getMenuParts(menu);
			const focusable = focusableInside(trigger?.parentElement);
			const elements = [focusable, content].filter(Boolean);
			elements.forEach((el) => {
				el.addEventListener("keydown", this.onKey);
			});
			return { menu, trigger: focusable, content };
		});
	},

	unbindListeners() {
		this.parts?.forEach(({ trigger, content }) => {
			trigger?.removeEventListener("keydown", this.onKey);
			content?.removeEventListener("keydown", this.onKey);
		});
	},

	onKey(e) {
		if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
		if (!this.parts?.length) return;

		// Active menu = the open one if any, else the one containing the focused element
		const active = document.activeElement;
		let currentIdx = this.parts.findIndex(
			({ menu }) => menu.getAttribute("data-state") === "open",
		);
		if (currentIdx === -1) {
			currentIdx = this.parts.findIndex(
				({ trigger, content }) =>
					(trigger && (trigger === active || trigger.contains(active))) ||
					content?.contains(active),
			);
		}
		if (currentIdx === -1) return;

		const dir = e.key === "ArrowRight" ? 1 : -1;
		const nextIdx = (currentIdx + dir + this.parts.length) % this.parts.length;
		if (nextIdx === currentIdx) return;

		e.preventDefault();
		e.stopPropagation();

		const current = this.parts[currentIdx];
		const next = this.parts[nextIdx];
		const wasOpen = current.menu.getAttribute("data-state") === "open";

		if (wasOpen) {
			// Trigger close on current menu via its hook through a click on the trigger.
			// Falling back to a state flip if the click handler is missing.
			current.trigger?.click();
			// Open next via its trigger click; the menu's hook handles positioning.
			requestAnimationFrame(() => {
				next.trigger?.click();
				next.trigger?.focus();
			});
		} else {
			next.trigger?.focus();
		}
	},
};
