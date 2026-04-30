// Hook for the <.tooltip> component.
// Opens on hover/focus of the trigger; closes on leave/blur. The
// trigger wrapper has `display: contents` (no box), so pointer events
// won't fire on it directly — we attach listeners to the focusable
// child element instead, mirroring the pattern used in `hover_card.js`.

import { position } from "./_position";

function focusableInside(wrapper) {
	return (
		wrapper.querySelector("button,a,[role='button'],[tabindex]") || wrapper
	);
}

function setup() {
	const newTriggerWrap = this.el.querySelector(
		':scope > [data-slot="tooltip-trigger"]',
	);
	const newContent = document.getElementById(`${this.el.id}-content`);
	if (newContent && newContent.parentElement !== document.body) {
		document.body.appendChild(newContent);
	}
	const newTrigger = focusableInside(newTriggerWrap);

	if (this.trigger && this.trigger !== newTrigger) {
		this.trigger.removeEventListener("pointerenter", this.onEnter);
		this.trigger.removeEventListener("pointerleave", this.onLeave);
		this.trigger.removeEventListener("focus", this.onFocus);
		this.trigger.removeEventListener("blur", this.onBlur);
	}
	if (this.trigger !== newTrigger) {
		newTrigger.addEventListener("pointerenter", this.onEnter);
		newTrigger.addEventListener("pointerleave", this.onLeave);
		newTrigger.addEventListener("focus", this.onFocus);
		newTrigger.addEventListener("blur", this.onBlur);
	}

	this.trigger = newTrigger;
	this.content = newContent;
	this.trigger.setAttribute("aria-describedby", this.content.id);
}

function teardown() {
	clearTimeout(this.openTimer);
	if (this.trigger) {
		this.trigger.removeEventListener("pointerenter", this.onEnter);
		this.trigger.removeEventListener("pointerleave", this.onLeave);
		this.trigger.removeEventListener("focus", this.onFocus);
		this.trigger.removeEventListener("blur", this.onBlur);
	}
	window.removeEventListener("resize", this.onWindowResize);
	window.removeEventListener("scroll", this.onWindowResize, true);
	this.content?.remove();
}

function isOpen(el) {
	return el.getAttribute("data-state") === "open";
}

function open() {
	if (isOpen(this.el)) return;
	position(this.content, this.trigger, {
		side: this.el.dataset.side,
		align: this.el.dataset.align,
		sideOffset: parseInt(this.el.dataset.sideOffset, 10),
	});
	this.el.setAttribute("data-state", "open");
	this.content.setAttribute("data-state", "open");
	window.addEventListener("resize", this.onWindowResize);
	window.addEventListener("scroll", this.onWindowResize, true);
}

function close() {
	if (!isOpen(this.el)) return;
	this.el.setAttribute("data-state", "closed");
	this.content.setAttribute("data-state", "closed");
	window.removeEventListener("resize", this.onWindowResize);
	window.removeEventListener("scroll", this.onWindowResize, true);
}

export const TooltipHook = {
	mounted() {
		this.openTimer = null;
		this.onEnter = this.onEnter.bind(this);
		this.onLeave = this.onLeave.bind(this);
		this.onFocus = this.onFocus.bind(this);
		this.onBlur = this.onBlur.bind(this);
		this.onWindowResize = this.onWindowResize.bind(this);
		setup.call(this);
	},
	updated() {
		setup.call(this);
	},
	destroyed() {
		teardown.call(this);
	},
	onEnter() {
		this.openTimer = setTimeout(
			() => open.call(this),
			parseInt(this.el.dataset.delay, 10),
		);
	},
	onLeave() {
		clearTimeout(this.openTimer);
		close.call(this);
	},
	onFocus() {
		clearTimeout(this.openTimer);
		open.call(this);
	},
	onBlur() {
		close.call(this);
	},
	onWindowResize() {
		if (!isOpen(this.el)) return;
		position(this.content, this.trigger, {
			side: this.el.dataset.side,
			align: this.el.dataset.align,
			sideOffset: parseInt(this.el.dataset.sideOffset, 10),
		});
	},
};
