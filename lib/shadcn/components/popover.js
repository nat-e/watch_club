// Hook for the <.popover> component (lib/watch_club_web/components/ui/popover.ex).
// Same shape as `dropdown_menu.js`'s root hook, minus the menu-specific
// item navigation. Click outside / ESC dismiss.

import { position } from "./_position";

function focusableInside(wrapper) {
	return (
		wrapper.querySelector("button,a,[role='button'],[tabindex]") || wrapper
	);
}

function setupListeners() {
	const newTriggerWrap = this.el.querySelector(
		':scope > [data-slot="popover-trigger"]',
	);
	const newContent = document.getElementById(`${this.el.id}-content`);
	if (newContent && newContent.parentElement !== document.body) {
		document.body.appendChild(newContent);
	}
	const newTrigger = focusableInside(newTriggerWrap);

	if (this.triggerWrap && this.triggerWrap !== newTriggerWrap) {
		this.triggerWrap.removeEventListener("click", this.onTriggerClick);
	}
	if (this.triggerWrap !== newTriggerWrap) {
		newTriggerWrap.addEventListener("click", this.onTriggerClick);
	}

	this.triggerWrap = newTriggerWrap;
	this.content = newContent;
	this.trigger = newTrigger;

	this.trigger.setAttribute("aria-haspopup", "dialog");
	this.trigger.setAttribute("aria-expanded", this.isOpen() ? "true" : "false");
	this.trigger.setAttribute("aria-controls", this.content.id);
}

export const PopoverHook = {
	mounted() {
		this.onTriggerClick = this.onTriggerClick.bind(this);
		this.onDocPointerDown = this.onDocPointerDown.bind(this);
		this.onWindowResize = this.onWindowResize.bind(this);
		this.onContentKey = this.onContentKey.bind(this);
		setupListeners.call(this);
		this.content.addEventListener("keydown", this.onContentKey);
	},
	updated() {
		setupListeners.call(this);
	},
	destroyed() {
		document.removeEventListener("pointerdown", this.onDocPointerDown, true);
		window.removeEventListener("resize", this.onWindowResize);
		window.removeEventListener("scroll", this.onWindowResize, true);
		this.content?.removeEventListener("keydown", this.onContentKey);
		this.content?.remove();
	},
	isOpen() {
		return this.el.getAttribute("data-state") === "open";
	},
	open() {
		if (this.isOpen()) return;
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
	onTriggerClick(e) {
		e.preventDefault();
		if (this.isOpen()) this.close();
		else this.open();
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
	onContentKey(e) {
		if (e.key === "Escape" && this.isOpen()) {
			e.preventDefault();
			this.close();
		}
	},
};
