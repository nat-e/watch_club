// Hook for the <.hover_card> component.
// Opens on hover/focus of the trigger; closes after a delay when both
// trigger and content are unhovered (so the user can travel to the
// content without it disappearing).

import { position } from "./_position";

function focusableInside(wrapper) {
	return (
		wrapper.querySelector("button,a,[role='button'],[tabindex]") || wrapper
	);
}

function setup() {
	const newTriggerWrap = this.el.querySelector(
		':scope > [data-slot="hover-card-trigger"]',
	);
	const newContent = document.getElementById(`${this.el.id}-content`);
	if (newContent && newContent.parentElement !== document.body) {
		document.body.appendChild(newContent);
	}
	const newTrigger = focusableInside(newTriggerWrap);

	if (this.trigger && this.trigger !== newTrigger) {
		this.trigger.removeEventListener("pointerenter", this.onTriggerEnter);
		this.trigger.removeEventListener("pointerleave", this.onTriggerLeave);
		this.trigger.removeEventListener("focus", this.onTriggerFocus);
		this.trigger.removeEventListener("blur", this.onTriggerBlur);
	}
	if (this.content && this.content !== newContent) {
		this.content.removeEventListener("pointerenter", this.onContentEnter);
		this.content.removeEventListener("pointerleave", this.onContentLeave);
	}
	if (this.trigger !== newTrigger) {
		newTrigger.addEventListener("pointerenter", this.onTriggerEnter);
		newTrigger.addEventListener("pointerleave", this.onTriggerLeave);
		newTrigger.addEventListener("focus", this.onTriggerFocus);
		newTrigger.addEventListener("blur", this.onTriggerBlur);
	}
	if (this.content !== newContent) {
		newContent.addEventListener("pointerenter", this.onContentEnter);
		newContent.addEventListener("pointerleave", this.onContentLeave);
	}

	this.triggerWrap = newTriggerWrap;
	this.trigger = newTrigger;
	this.content = newContent;

	this.trigger.setAttribute("aria-haspopup", "dialog");
	this.trigger.setAttribute("aria-controls", this.content.id);
}

function teardown() {
	clearTimeout(this.openTimer);
	clearTimeout(this.closeTimer);
	if (this.trigger) {
		this.trigger.removeEventListener("pointerenter", this.onTriggerEnter);
		this.trigger.removeEventListener("pointerleave", this.onTriggerLeave);
		this.trigger.removeEventListener("focus", this.onTriggerFocus);
		this.trigger.removeEventListener("blur", this.onTriggerBlur);
	}
	if (this.content) {
		this.content.removeEventListener("pointerenter", this.onContentEnter);
		this.content.removeEventListener("pointerleave", this.onContentLeave);
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
		alignOffset: parseInt(this.el.dataset.alignOffset, 10),
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

export const HoverCardHook = {
	mounted() {
		this.openTimer = null;
		this.closeTimer = null;
		this.onTriggerEnter = this.onTriggerEnter.bind(this);
		this.onTriggerLeave = this.onTriggerLeave.bind(this);
		this.onTriggerFocus = this.onTriggerFocus.bind(this);
		this.onTriggerBlur = this.onTriggerBlur.bind(this);
		this.onContentEnter = this.onContentEnter.bind(this);
		this.onContentLeave = this.onContentLeave.bind(this);
		this.onWindowResize = this.onWindowResize.bind(this);
		setup.call(this);
	},
	updated() {
		setup.call(this);
	},
	destroyed() {
		teardown.call(this);
	},
	onTriggerEnter() {
		clearTimeout(this.closeTimer);
		this.openTimer = setTimeout(
			() => open.call(this),
			parseInt(this.el.dataset.openDelay, 10),
		);
	},
	onTriggerLeave() {
		clearTimeout(this.openTimer);
		this.closeTimer = setTimeout(
			() => close.call(this),
			parseInt(this.el.dataset.closeDelay, 10),
		);
	},
	onTriggerFocus() {
		clearTimeout(this.closeTimer);
		open.call(this);
	},
	onTriggerBlur() {
		close.call(this);
	},
	onContentEnter() {
		clearTimeout(this.closeTimer);
	},
	onContentLeave() {
		this.closeTimer = setTimeout(
			() => close.call(this),
			parseInt(this.el.dataset.closeDelay, 10),
		);
	},
	onWindowResize() {
		if (!isOpen(this.el)) return;
		position(this.content, this.trigger, {
			side: this.el.dataset.side,
			align: this.el.dataset.align,
			sideOffset: parseInt(this.el.dataset.sideOffset, 10),
			alignOffset: parseInt(this.el.dataset.alignOffset, 10),
		});
	},
};
