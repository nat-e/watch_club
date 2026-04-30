// Hook for the <.slider> component (lib/watch_club_web/components/ui/slider.ex).
// Drives drag, click, keyboard navigation, and visual updates for single,
// range, and multi-thumb sliders. Each thumb is paired with a hidden
// <input type="range"> by data-thumb-index; the inputs carry the value
// (and provide form submission) while we paint the track and thumb chrome.

function setup() {
	this.track = this.el.querySelector('[data-slot="slider-track"]');
	this.range = this.el.querySelector('[data-slot="slider-range"]');
	this.inputs = Array.from(
		this.el.querySelectorAll('[data-slot="slider-input"]'),
	);
	this.thumbs = Array.from(
		this.el.querySelectorAll('[data-slot="slider-thumb"]'),
	);

	this.minSteps = Number(
		this.el.getAttribute("data-min-steps-between-thumbs") || 0,
	);
	this.activeIndex = null;

	this.onPointerDown = this.onPointerDown.bind(this);
	this.onPointerMove = this.onPointerMove.bind(this);
	this.onPointerUp = this.onPointerUp.bind(this);

	this.el.addEventListener("pointerdown", this.onPointerDown);

	this.thumbs.forEach((thumb, index) => {
		const input = this.inputs[index];
		thumb.setAttribute("tabindex", input.disabled ? "-1" : "0");

		const onKeyDown = (e) => this.handleKeyDown(e, index);
		const onInput = () => this.render();

		thumb.addEventListener("keydown", onKeyDown);
		input.addEventListener("input", onInput);
		input.addEventListener("change", onInput);

		thumb._cleanup = () => {
			thumb.removeEventListener("keydown", onKeyDown);
			input.removeEventListener("input", onInput);
			input.removeEventListener("change", onInput);
		};
	});

	this.render();
}

function teardown() {
	this.el.removeEventListener("pointerdown", this.onPointerDown);
	document.removeEventListener("pointermove", this.onPointerMove);
	document.removeEventListener("pointerup", this.onPointerUp);
	this.thumbs.forEach((thumb) => {
		thumb._cleanup?.();
	});
}

function vertical(el) {
	return el.getAttribute("data-orientation") === "vertical";
}

function pct(input) {
	const min = Number(input.min || 0);
	const max = Number(input.max || 100);
	const value = Number(input.value || 0);
	if (max === min) return 0;
	return ((value - min) / (max - min)) * 100;
}

function render() {
	const percentages = this.inputs.map((input) => pct(input));
	// Single-thumb: range fills from origin to the thumb.
	// Multi-thumb: range spans between the lowest and highest thumb.
	const lo = percentages.length === 1 ? 0 : Math.min(...percentages);
	const hi =
		percentages.length === 1 ? percentages[0] : Math.max(...percentages);

	if (vertical(this.el)) {
		this.range.style.bottom = `${lo}%`;
		this.range.style.height = `${hi - lo}%`;
		this.range.style.left = "0";
		this.range.style.right = "0";
	} else {
		this.range.style.left = `${lo}%`;
		this.range.style.width = `${hi - lo}%`;
		this.range.style.top = "0";
		this.range.style.bottom = "0";
	}

	this.thumbs.forEach((thumb, index) => {
		const p = percentages[index];
		if (vertical(this.el)) {
			thumb.style.left = "50%";
			thumb.style.bottom = `${p}%`;
			thumb.style.top = "auto";
			thumb.style.transform = "translate(-50%, 50%)";
		} else {
			thumb.style.top = "50%";
			thumb.style.left = `${p}%`;
			thumb.style.bottom = "auto";
			thumb.style.transform = "translate(-50%, -50%)";
		}
	});
}

function valueFromPointer(e) {
	const rect = this.track.getBoundingClientRect();
	const min = Number(this.inputs[0].min || 0);
	const max = Number(this.inputs[0].max || 100);
	const step = Number(this.inputs[0].step || 1);

	let p;
	if (vertical(this.el)) {
		p = (rect.bottom - e.clientY) / rect.height;
	} else {
		p = (e.clientX - rect.left) / rect.width;
	}
	p = Math.max(0, Math.min(1, p));

	const raw = min + p * (max - min);
	const stepped = Math.round((raw - min) / step) * step + min;
	return Math.max(min, Math.min(max, stepped));
}

function closestIndex(value) {
	let best = 0;
	let bestDist = Infinity;
	this.inputs.forEach((input, i) => {
		const d = Math.abs(Number(input.value) - value);
		if (d < bestDist) {
			bestDist = d;
			best = i;
		}
	});
	return best;
}

function clampForIndex(index, value) {
	const min = Number(this.inputs[0].min || 0);
	const max = Number(this.inputs[0].max || 100);
	const step = Number(this.inputs[0].step || 1);
	const gap = step * this.minSteps;

	const lower = index > 0 ? Number(this.inputs[index - 1].value) + gap : min;
	const upper =
		index < this.inputs.length - 1
			? Number(this.inputs[index + 1].value) - gap
			: max;

	return Math.max(lower, Math.min(upper, value));
}

function setValue(index, raw) {
	const input = this.inputs[index];
	const v = clampForIndex.call(this, index, raw);
	const before = input.value;
	input.value = v;
	if (input.value !== before) {
		input.dispatchEvent(new Event("input", { bubbles: true }));
		input.dispatchEvent(new Event("change", { bubbles: true }));
	}
	this.render();
}

export const SliderHook = {
	mounted() {
		this.render = render.bind(this);
		setup.call(this);
	},
	updated() {
		teardown.call(this);
		setup.call(this);
	},
	destroyed() {
		teardown.call(this);
	},
	onPointerDown(e) {
		if (this.inputs.some((i) => i.disabled)) return;
		if (e.button !== 0 && e.pointerType === "mouse") return;
		e.preventDefault();
		const value = valueFromPointer.call(this, e);
		this.activeIndex = closestIndex.call(this, value);
		this.thumbs[this.activeIndex].focus();
		setValue.call(this, this.activeIndex, value);
		document.addEventListener("pointermove", this.onPointerMove);
		document.addEventListener("pointerup", this.onPointerUp);
	},
	onPointerMove(e) {
		if (this.activeIndex === null) return;
		setValue.call(this, this.activeIndex, valueFromPointer.call(this, e));
	},
	onPointerUp() {
		this.activeIndex = null;
		document.removeEventListener("pointermove", this.onPointerMove);
		document.removeEventListener("pointerup", this.onPointerUp);
	},
	handleKeyDown(e, index) {
		const input = this.inputs[index];
		if (input.disabled) return;
		const step = Number(input.step || 1);
		const min = Number(input.min || 0);
		const max = Number(input.max || 100);
		let v = Number(input.value || 0);

		const inc = vertical(this.el)
			? ["ArrowUp", "ArrowRight"]
			: ["ArrowRight", "ArrowUp"];
		const dec = vertical(this.el)
			? ["ArrowDown", "ArrowLeft"]
			: ["ArrowLeft", "ArrowDown"];

		if (inc.includes(e.key)) v += step;
		else if (dec.includes(e.key)) v -= step;
		else if (e.key === "Home") v = min;
		else if (e.key === "End") v = max;
		else if (e.key === "PageUp") v += step * 10;
		else if (e.key === "PageDown") v -= step * 10;
		else return;

		e.preventDefault();
		v = Math.max(min, Math.min(max, v));
		setValue.call(this, index, v);
	},
};
