// Hook for the <.sidebar_provider> component
// (lib/watch_club_web/components/ui/sidebar.ex). Manages expanded/collapsed
// state, persists it via the `sidebar_state`, and switches between desktop layout and a mobile
// slide-in overlay.

const MOBILE_QUERY = "(max-width: 767px)";

function setup() {
	this.mql = window.matchMedia(MOBILE_QUERY);
	this.applyMobile = applyMobile.bind(this);
	this.applyMobile();
	this.mql.addEventListener("change", this.applyMobile);

	this.onClick = onClick.bind(this);
	this.el.addEventListener("click", this.onClick);

	this.onPointerOver = onPointerOver.bind(this);
	this.onPointerOut = onPointerOut.bind(this);
	this.onFocusIn = onFocusIn.bind(this);
	this.onFocusOut = onFocusOut.bind(this);
	this.el.addEventListener("pointerover", this.onPointerOver);
	this.el.addEventListener("pointerout", this.onPointerOut);
	this.el.addEventListener("focusin", this.onFocusIn);
	this.el.addEventListener("focusout", this.onFocusOut);

	this.onToggleEvent = () => toggle.call(this);
	this.el.addEventListener("wc:sidebar-toggle", this.onToggleEvent);
}

function teardown() {
	this.el.removeEventListener("click", this.onClick);
	this.el.removeEventListener("pointerover", this.onPointerOver);
	this.el.removeEventListener("pointerout", this.onPointerOut);
	this.el.removeEventListener("focusin", this.onFocusIn);
	this.el.removeEventListener("focusout", this.onFocusOut);
	this.el.removeEventListener("wc:sidebar-toggle", this.onToggleEvent);
	this.mql.removeEventListener("change", this.applyMobile);
}

function applyMobile() {
	if (this.mql.matches) {
		this.el.setAttribute("data-mobile", "true");
	} else {
		this.el.removeAttribute("data-mobile");
		this.el.removeAttribute("data-mobile-open");
	}
}

function toggle() {
	if (this.el.hasAttribute("data-mobile")) {
		if (this.el.hasAttribute("data-mobile-open")) {
			this.el.removeAttribute("data-mobile-open");
		} else {
			this.el.setAttribute("data-mobile-open", "true");
		}
		return;
	}

	const next =
		this.el.getAttribute("data-state") === "collapsed"
			? "expanded"
			: "collapsed";
	this.el.setAttribute("data-state", next);
}

function onClick(e) {
	const trigger = e.target.closest("[data-sidebar-toggle]");
	if (trigger && this.el.contains(trigger)) {
		toggle.call(this);
		return;
	}

	if (!this.el.hasAttribute("data-mobile-open")) return;
	if (e.target.closest('[data-slot="sidebar-container"]')) return;
	this.el.removeAttribute("data-mobile-open");
}

function tooltipFor(button) {
	const item = button.closest('[data-slot="sidebar-menu-item"]');
	return item?.querySelector('[data-slot="sidebar-menu-tooltip"]');
}

function showTooltip(button) {
	if (this.el.getAttribute("data-state") !== "collapsed") return;
	if (this.el.hasAttribute("data-mobile")) return;
	const tooltip = tooltipFor(button);
	if (!tooltip) return;
	const rect = button.getBoundingClientRect();
	const sidebar = button.closest('[data-slot="sidebar"]');
	const isRight = sidebar?.getAttribute("data-side") === "right";
	tooltip.style.top = `${rect.top + rect.height / 2}px`;
	if (isRight) {
		tooltip.style.left = `${rect.left - 4}px`;
		tooltip.style.transform = "translate(-100%, -50%)";
	} else {
		tooltip.style.left = `${rect.right + 4}px`;
		tooltip.style.transform = "translateY(-50%)";
	}
	tooltip.setAttribute("data-show", "true");
}

function hideTooltip(button) {
	const tooltip = tooltipFor(button);
	if (tooltip) tooltip.removeAttribute("data-show");
}

function onPointerOver(e) {
	const button = e.target.closest('[data-slot="sidebar-menu-button"]');
	if (button) showTooltip.call(this, button);
}

function onPointerOut(e) {
	const button = e.target.closest('[data-slot="sidebar-menu-button"]');
	if (!button) return;
	if (button.contains(e.relatedTarget)) return;
	hideTooltip.call(this, button);
}

function onFocusIn(e) {
	const button = e.target.closest('[data-slot="sidebar-menu-button"]');
	if (button) showTooltip.call(this, button);
}

function onFocusOut(e) {
	const button = e.target.closest('[data-slot="sidebar-menu-button"]');
	if (button) hideTooltip.call(this, button);
}

export const WCSidebarHook = {
	mounted() {
		setup.call(this);
	},
	destroyed() {
		teardown.call(this);
	},
};
