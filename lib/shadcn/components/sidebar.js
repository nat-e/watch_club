// Hook for the <.sidebar_provider> component
// (lib/watch_club_web/components/ui/sidebar.ex). Manages expanded/collapsed
// state, persists it via the `sidebar_state` cookie, handles the Cmd/Ctrl+B
// keyboard shortcut, and switches between desktop layout and a mobile
// slide-in overlay.

const COOKIE_NAME = "sidebar_state";
const COOKIE_MAX_AGE = 60 * 60 * 24 * 7;
const KEYBOARD_SHORTCUT = "b";
const MOBILE_QUERY = "(max-width: 767px)";

function readCookie(name) {
	const match = document.cookie.match(new RegExp(`(?:^|; )${name}=([^;]*)`));
	return match ? decodeURIComponent(match[1]) : null;
}

function writeCookie(name, value) {
	// biome-ignore lint/suspicious/noDocumentCookie: Cookie Store API lacks broad browser support
	document.cookie = `${name}=${encodeURIComponent(value)}; path=/; max-age=${COOKIE_MAX_AGE}`;
}

function setup() {
	this.cookieName = `${COOKIE_NAME}:${this.el.id}`;
	const stored = readCookie(this.cookieName);
	if (stored === "expanded" || stored === "collapsed") {
		this.el.setAttribute("data-state", stored);
	}

	this.mql = window.matchMedia(MOBILE_QUERY);
	this.applyMobile = applyMobile.bind(this);
	this.applyMobile();
	this.mql.addEventListener("change", this.applyMobile);

	this.onClick = onClick.bind(this);
	this.el.addEventListener("click", this.onClick);

	this.onKeydown = onKeydown.bind(this);
	window.addEventListener("keydown", this.onKeydown);

	this.onPointerOver = onPointerOver.bind(this);
	this.onPointerOut = onPointerOut.bind(this);
	this.onFocusIn = onFocusIn.bind(this);
	this.onFocusOut = onFocusOut.bind(this);
	this.el.addEventListener("pointerover", this.onPointerOver);
	this.el.addEventListener("pointerout", this.onPointerOut);
	this.el.addEventListener("focusin", this.onFocusIn);
	this.el.addEventListener("focusout", this.onFocusOut);
}

function teardown() {
	this.el.removeEventListener("click", this.onClick);
	this.el.removeEventListener("pointerover", this.onPointerOver);
	this.el.removeEventListener("pointerout", this.onPointerOut);
	this.el.removeEventListener("focusin", this.onFocusIn);
	this.el.removeEventListener("focusout", this.onFocusOut);
	this.mql.removeEventListener("change", this.applyMobile);
	window.removeEventListener("keydown", this.onKeydown);
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
	writeCookie(this.cookieName, next);
}

function onClick(e) {
	const trigger = e.target.closest("[data-sidebar-toggle]");
	if (!trigger || !this.el.contains(trigger)) return;
	toggle.call(this);
}

function onKeydown(e) {
	if (e.key !== KEYBOARD_SHORTCUT) return;
	if (!(e.metaKey || e.ctrlKey)) return;
	e.preventDefault();
	toggle.call(this);
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
