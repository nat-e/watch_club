// Hook for the <.calendar> component (lib/watch_club_web/components/ui/calendar.ex).
// The server pre-renders a 6-row × 7-day grid; this hook updates it in
// place when the user navigates months (chevrons, dropdowns, PageUp/Down).
// Day clicks update hidden inputs and dispatch input/change so the value
// flows into the surrounding form. Programmatic updates accept a
// `calendar:set` CustomEvent on the root.

const DAY_SELECTOR = '[data-slot="calendar-day"]';

export const CalendarHook = {
	mounted() {
		this.refreshRefs();
		this.bindListeners();
	},

	// LiveView morphs may replace child elements when attrs change (e.g.
	// Storybook playground swapping mode/caption_layout). Re-cache and
	// re-bind from scratch to avoid stale references and double listeners.
	updated() {
		this.refreshRefs();
		this.bindListeners();
	},

	destroyed() {
		this.unbindListeners();
	},

	refreshRefs() {
		this.mode = this.el.getAttribute("data-mode");
		this.captionLayout = this.el.getAttribute("data-caption-layout");
		this.month = parseISO(this.el.getAttribute("data-month"));
		this.showWeekNumbers =
			this.el.getAttribute("data-show-week-numbers") === "true";
		this.disabledDates = new Set(
			JSON.parse(this.el.getAttribute("data-disabled-dates") || "[]"),
		);
		this.monthNames = JSON.parse(this.el.getAttribute("data-month-names"));

		const inputs = Array.from(
			this.el.querySelectorAll(':scope > [data-slot="calendar-input"]'),
		);
		this.singleInput = inputs.find((i) => !i.hasAttribute("data-range"));
		this.fromInput = inputs.find((i) => i.dataset.range === "from");
		this.toInput = inputs.find((i) => i.dataset.range === "to");

		this.prevButton = this.el.querySelector(
			'[data-slot="calendar-nav-button"][data-direction="prev"]',
		);
		this.nextButton = this.el.querySelector(
			'[data-slot="calendar-nav-button"][data-direction="next"]',
		);
		this.monthSelect = this.el.querySelector(
			'[data-slot="calendar-caption-select"][data-axis="month"]',
		);
		this.yearSelect = this.el.querySelector(
			'[data-slot="calendar-caption-select"][data-axis="year"]',
		);
		this.monthLabel = this.el.querySelector(
			'[data-slot="calendar-caption-month-label"]',
		);
		this.yearLabel = this.el.querySelector(
			'[data-slot="calendar-caption-year-label"]',
		);
		this.tableBody = this.el.querySelector(
			'[data-slot="calendar-table"] tbody',
		);

		if (this.mode === "range") {
			this.from = this.fromInput?.value ? parseISO(this.fromInput.value) : null;
			this.to = this.toInput?.value ? parseISO(this.toInput.value) : null;
		} else {
			this.from = this.singleInput?.value
				? parseISO(this.singleInput.value)
				: null;
			this.to = null;
		}
	},

	bindListeners() {
		this.unbindListeners();
		this._listeners = [];

		this.on(this.prevButton, "click", (e) => {
			e.preventDefault();
			this.shiftMonth(-1);
		});
		this.on(this.nextButton, "click", (e) => {
			e.preventDefault();
			this.shiftMonth(1);
		});
		if (this.monthSelect) {
			this.on(this.monthSelect, "change", (e) =>
				this.setMonthValue(
					new Date(
						this.month.getFullYear(),
						parseInt(e.target.value, 10) - 1,
						1,
					),
				),
			);
		}
		if (this.yearSelect) {
			this.on(this.yearSelect, "change", (e) =>
				this.setMonthValue(
					new Date(parseInt(e.target.value, 10), this.month.getMonth(), 1),
				),
			);
		}
		this.on(this.tableBody, "click", (e) => this.onDayClick(e));
		this.on(this.el, "keydown", (e) => this.onKey(e));
		this.on(this.el, "calendar:set", (e) => this.onProgrammaticSet(e));
	},

	on(target, evt, fn) {
		if (!target) return;
		target.addEventListener(evt, fn);
		this._listeners.push([target, evt, fn]);
	},

	unbindListeners() {
		if (!this._listeners) return;
		for (const [target, evt, fn] of this._listeners) {
			target.removeEventListener(evt, fn);
		}
		this._listeners = [];
	},

	shiftMonth(delta) {
		const m = new Date(
			this.month.getFullYear(),
			this.month.getMonth() + delta,
			1,
		);
		this.setMonthValue(m);
	},

	setMonthValue(date) {
		this.month = new Date(date.getFullYear(), date.getMonth(), 1);
		this.el.setAttribute("data-month", isoDate(this.month));
		this.renderCaption();
		this.renderGrid();
	},

	renderCaption() {
		if (this.monthLabel)
			this.monthLabel.textContent = this.monthNames[this.month.getMonth()];
		if (this.yearLabel)
			this.yearLabel.textContent = String(this.month.getFullYear());
		if (this.monthSelect)
			this.monthSelect.value = String(this.month.getMonth() + 1);
		if (this.yearSelect)
			this.yearSelect.value = String(this.month.getFullYear());
	},

	renderGrid() {
		const monthFirst = this.month;
		const lastOfMonth = new Date(
			this.month.getFullYear(),
			this.month.getMonth() + 1,
			0,
		);
		const weekdayMon = (d) => (d.getDay() + 6) % 7;
		const start = new Date(monthFirst);
		start.setDate(start.getDate() - weekdayMon(monthFirst));

		const allDays = [];
		for (let i = 0; i < 42; i++) {
			const d = new Date(start);
			d.setDate(start.getDate() + i);
			allDays.push(d);
		}

		let visibleRows = 6;
		for (let row = 5; row >= 0; row--) {
			const week = allDays.slice(row * 7, row * 7 + 7);
			if (week.some((d) => d <= lastOfMonth)) {
				visibleRows = row + 1;
				break;
			}
		}

		const todayStr = isoDate(new Date());
		const rows = Array.from(this.tableBody.querySelectorAll(":scope > tr"));

		for (let r = 0; r < rows.length; r++) {
			const tr = rows[r];
			if (r >= visibleRows) {
				tr.style.display = "none";
				continue;
			}
			tr.style.display = "";
			const cells = Array.from(tr.querySelectorAll(":scope > td"));
			let cellIdx = 0;

			if (this.showWeekNumbers) {
				const weekNumCell = cells[cellIdx++];
				if (weekNumCell)
					weekNumCell.textContent = isoWeekNumber(allDays[r * 7]);
			}

			for (let c = 0; c < 7; c++) {
				const td = cells[cellIdx++];
				if (!td) continue;
				const btn = td.querySelector(DAY_SELECTOR);
				if (!btn) continue;
				const day = allDays[r * 7 + c];
				const iso = isoDate(day);
				btn.textContent = day.getDate();
				btn.setAttribute("data-date", iso);
				btn.setAttribute("aria-label", longDateLabel(day));
				btn.setAttribute("tabindex", "-1");

				if (day < monthFirst || day > lastOfMonth) {
					btn.setAttribute("data-outside", "true");
				} else {
					btn.removeAttribute("data-outside");
				}
				if (iso === todayStr) {
					btn.setAttribute("data-today", "true");
				} else {
					btn.removeAttribute("data-today");
				}
				if (this.disabledDates.has(iso)) {
					btn.setAttribute("data-disabled", "true");
					btn.setAttribute("aria-disabled", "true");
				} else {
					btn.removeAttribute("data-disabled");
					btn.removeAttribute("aria-disabled");
				}
				this.applySelectionToButton(btn, day);
			}
		}
	},

	applySelectionToButton(btn, day) {
		btn.removeAttribute("data-selected-single");
		btn.removeAttribute("data-range-start");
		btn.removeAttribute("data-range-end");
		btn.removeAttribute("data-range-middle");

		if (this.mode === "single") {
			const isSel = this.from && sameDay(day, this.from);
			if (isSel) btn.setAttribute("data-selected-single", "true");
			btn.setAttribute("aria-pressed", isSel ? "true" : "false");
			return;
		}

		const isStart = this.from && sameDay(day, this.from);
		const isEnd = this.to && sameDay(day, this.to);
		const isMid = this.from && this.to && day > this.from && day < this.to;
		if (isStart) btn.setAttribute("data-range-start", "true");
		if (isEnd) btn.setAttribute("data-range-end", "true");
		if (isMid) btn.setAttribute("data-range-middle", "true");
		btn.setAttribute(
			"aria-pressed",
			isStart || isEnd || isMid ? "true" : "false",
		);
	},

	refreshSelectionDOM() {
		for (const btn of Array.from(this.el.querySelectorAll(DAY_SELECTOR))) {
			const day = parseISO(btn.getAttribute("data-date"));
			this.applySelectionToButton(btn, day);
		}
	},

	onDayClick(e) {
		const btn = e.target.closest(DAY_SELECTOR);
		if (!btn) return;
		if (btn.hasAttribute("data-disabled")) {
			e.preventDefault();
			return;
		}
		e.preventDefault();
		const day = parseISO(btn.getAttribute("data-date"));

		if (this.mode === "single") {
			this.from = this.from && sameDay(day, this.from) ? null : day;
			this.commitSingle();
		} else if (!this.from || (this.from && this.to)) {
			this.from = day;
			this.to = null;
			this.commitRange();
		} else if (day < this.from) {
			this.to = this.from;
			this.from = day;
			this.commitRange();
		} else {
			this.to = day;
			this.commitRange();
		}

		const lastOfMonth = new Date(
			this.month.getFullYear(),
			this.month.getMonth() + 1,
			0,
		);
		if (day < this.month || day > lastOfMonth) {
			this.setMonthValue(new Date(day.getFullYear(), day.getMonth(), 1));
		} else {
			this.refreshSelectionDOM();
		}
	},

	commitSingle() {
		if (!this.singleInput) return;
		const value = this.from ? isoDate(this.from) : "";
		if (this.singleInput.value !== value) {
			this.singleInput.value = value;
			dispatchInput(this.singleInput);
		}
	},

	commitRange() {
		const fromVal = this.from ? isoDate(this.from) : "";
		const toVal = this.to ? isoDate(this.to) : "";
		if (this.fromInput && this.fromInput.value !== fromVal) {
			this.fromInput.value = fromVal;
			dispatchInput(this.fromInput);
		}
		if (this.toInput && this.toInput.value !== toVal) {
			this.toInput.value = toVal;
			dispatchInput(this.toInput);
		}
	},

	onKey(e) {
		if (!e.target.matches(DAY_SELECTOR)) return;
		if (e.key === "PageUp") {
			e.preventDefault();
			this.shiftMonth(-1);
			return;
		}
		if (e.key === "PageDown") {
			e.preventDefault();
			this.shiftMonth(1);
			return;
		}
		if (e.key === "Enter" || e.key === " ") {
			e.preventDefault();
			e.target.click();
			return;
		}

		const days = Array.from(this.el.querySelectorAll(DAY_SELECTOR));
		const idx = days.indexOf(e.target);
		if (idx === -1) return;
		let newIdx = -1;
		if (e.key === "ArrowLeft") newIdx = idx - 1;
		else if (e.key === "ArrowRight") newIdx = idx + 1;
		else if (e.key === "ArrowUp") newIdx = idx - 7;
		else if (e.key === "ArrowDown") newIdx = idx + 7;
		else if (e.key === "Home") newIdx = idx - (idx % 7);
		else if (e.key === "End") newIdx = idx - (idx % 7) + 6;
		else return;

		if (newIdx >= 0 && newIdx < days.length) {
			e.preventDefault();
			days[newIdx].focus();
		}
	},

	onProgrammaticSet(e) {
		const detail = e.detail || {};
		if (this.mode === "single") {
			if ("date" in detail) {
				this.from = detail.date ? parseISO(detail.date) : null;
				this.commitSingle();
			}
		} else {
			if ("from" in detail)
				this.from = detail.from ? parseISO(detail.from) : null;
			if ("to" in detail) this.to = detail.to ? parseISO(detail.to) : null;
			this.commitRange();
		}
		const focusDate = this.from || this.to;
		if (focusDate) {
			this.setMonthValue(
				new Date(focusDate.getFullYear(), focusDate.getMonth(), 1),
			);
		} else {
			this.refreshSelectionDOM();
		}
	},
};

function isoDate(d) {
	const y = d.getFullYear();
	const m = String(d.getMonth() + 1).padStart(2, "0");
	const day = String(d.getDate()).padStart(2, "0");
	return `${y}-${m}-${day}`;
}

function parseISO(iso) {
	const [y, m, d] = iso.split("-").map(Number);
	return new Date(y, m - 1, d);
}

function sameDay(a, b) {
	return (
		a.getFullYear() === b.getFullYear() &&
		a.getMonth() === b.getMonth() &&
		a.getDate() === b.getDate()
	);
}

// ISO 8601 week number — week 1 is the week containing the year's first
// Thursday; weeks start on Monday.
function isoWeekNumber(d) {
	const target = new Date(d.valueOf());
	const dayNr = (d.getDay() + 6) % 7;
	target.setDate(target.getDate() - dayNr + 3);
	const firstThursday = target.valueOf();
	target.setMonth(0, 1);
	if (target.getDay() !== 4) {
		target.setMonth(0, 1 + ((4 - target.getDay() + 7) % 7));
	}
	return 1 + Math.ceil((firstThursday - target) / (7 * 24 * 3600 * 1000));
}

function longDateLabel(d) {
	return d.toLocaleDateString(undefined, {
		weekday: "long",
		year: "numeric",
		month: "long",
		day: "numeric",
	});
}

function dispatchInput(el) {
	el.dispatchEvent(new Event("input", { bubbles: true }));
	el.dispatchEvent(new Event("change", { bubbles: true }));
}
