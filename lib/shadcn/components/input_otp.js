// Hook for <.input_otp> (lib/watch_club_web/components/ui/input_otp.ex).
// Manages per-cell rendering, typing, paste, deletion, and arrow nav while
// keeping a single hidden <input> as the source of truth for forms.

function denyRegex(pattern) {
	const m = (pattern || "").match(/^\[([^\]]+)\]\*?$/);
	return m ? new RegExp(`[^${m[1]}]`, "g") : /[^\d]/g;
}

function setup() {
	this.input = this.el.querySelector('[data-slot="input-otp-input"]');
	this.slots = Array.from(
		this.el.querySelectorAll('[data-slot="input-otp-slot"]'),
	);
	this.length = this.slots.length;
	this.deny = denyRegex(this.input.getAttribute("pattern"));

	this.onFocus = this.onFocus.bind(this);
	this.onBlur = this.onBlur.bind(this);
	this.onKey = this.onKey.bind(this);
	this.onBeforeInput = this.onBeforeInput.bind(this);
	this.onPaste = this.onPaste.bind(this);
	this.onSlotMouseDown = this.onSlotMouseDown.bind(this);

	this.input.addEventListener("focus", this.onFocus);
	this.input.addEventListener("blur", this.onBlur);
	this.input.addEventListener("keydown", this.onKey);
	this.input.addEventListener("beforeinput", this.onBeforeInput);
	this.input.addEventListener("paste", this.onPaste);
	this.slots.forEach((s) => {
		s.addEventListener("mousedown", this.onSlotMouseDown);
	});

	this.render();
}

function teardown() {
	this.input?.removeEventListener("focus", this.onFocus);
	this.input?.removeEventListener("blur", this.onBlur);
	this.input?.removeEventListener("keydown", this.onKey);
	this.input?.removeEventListener("beforeinput", this.onBeforeInput);
	this.input?.removeEventListener("paste", this.onPaste);
	this.slots?.forEach((s) => {
		s.removeEventListener("mousedown", this.onSlotMouseDown);
	});
}

function caretIndex(input) {
	const v = input.value || "";
	return Math.min(v.length, input.maxLength || v.length);
}

function render() {
	const value = this.input.value || "";
	const focused = document.activeElement === this.input;
	const active = caretIndex(this.input);

	this.slots.forEach((slot, i) => {
		slot.textContent = value[i] || "";
		const isActive =
			focused &&
			(i === active || (i === this.length - 1 && active === this.length));
		if (isActive) slot.setAttribute("data-active", "true");
		else slot.removeAttribute("data-active");
		if (focused && i === active && active < this.length && !value[i]) {
			slot.setAttribute("data-caret", "true");
		} else {
			slot.removeAttribute("data-caret");
		}
	});

	if (this.input.getAttribute("aria-invalid") === "true") {
		this.el.setAttribute("data-aria-invalid", "true");
	} else {
		this.el.removeAttribute("data-aria-invalid");
	}
}

export const InputOtpHook = {
	mounted() {
		this.render = render.bind(this);
		setup.call(this);
	},
	updated() {
		this.render();
	},
	destroyed() {
		teardown.call(this);
	},
	onFocus() {
		this.render();
	},
	onBlur() {
		this.render();
	},
	onKey(e) {
		if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
			e.preventDefault();
			const idx = caretIndex(this.input);
			const next =
				e.key === "ArrowLeft"
					? Math.max(0, idx - 1)
					: Math.min(this.length, idx + 1);
			this.input.value = this.input.value.slice(0, next);
			this.input.setSelectionRange(next, next);
			this.render();
		} else if (e.key === "Home") {
			e.preventDefault();
			this.input.value = "";
			this.render();
		} else if (e.key === "End") {
			e.preventDefault();
			this.input.setSelectionRange(
				this.input.value.length,
				this.input.value.length,
			);
			this.render();
		}
	},
	onBeforeInput(e) {
		if (e.inputType === "insertText") {
			const data = (e.data || "").replace(this.deny, "");
			if (!data) {
				e.preventDefault();
				return;
			}
			e.preventDefault();
			const remaining = this.length - this.input.value.length;
			this.input.value = (this.input.value + data).slice(0, this.length);
			void remaining;
			this.input.setSelectionRange(
				this.input.value.length,
				this.input.value.length,
			);
			this.input.dispatchEvent(new Event("input", { bubbles: true }));
			this.render();
		} else if (e.inputType === "deleteContentBackward") {
			e.preventDefault();
			this.input.value = this.input.value.slice(0, -1);
			this.input.setSelectionRange(
				this.input.value.length,
				this.input.value.length,
			);
			this.input.dispatchEvent(new Event("input", { bubbles: true }));
			this.render();
		}
	},
	onPaste(e) {
		e.preventDefault();
		const text = (e.clipboardData?.getData("text") || "")
			.replace(this.deny, "")
			.slice(0, this.length);
		this.input.value = text;
		this.input.setSelectionRange(text.length, text.length);
		this.input.dispatchEvent(new Event("input", { bubbles: true }));
		this.render();
	},
	onSlotMouseDown(e) {
		e.preventDefault();
		this.input.focus();
		this.render();
	},
};
