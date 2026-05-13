// Shared positioning helpers used by popover-style overlays
// (popover, tooltip, hover-card, select, combobox, ...).
//
// Float a `position: fixed` element next to a trigger, flip side when room
// runs out, clamp to viewport,
// and write CSS variables for available height and transform-origin so
// animations spring from the correct edge.

export function oppositeSide(side) {
	return { top: "bottom", bottom: "top", left: "right", right: "left" }[side];
}

export function transformOrigin(side, align) {
	const v = side === "bottom" ? "top" : side === "top" ? "bottom" : null;
	const h = side === "right" ? "left" : side === "left" ? "right" : null;
	if (v) {
		const x = align === "start" ? "left" : align === "end" ? "right" : "center";
		return `${x} ${v}`;
	}
	const y = align === "start" ? "top" : align === "end" ? "bottom" : "center";
	return `${h} ${y}`;
}

export function position(content, anchor, opts = {}) {
	const sideOffset = opts.sideOffset ?? 4;
	const alignOffset = opts.alignOffset ?? 0;
	const align = opts.align ?? "center";
	let side = opts.side ?? "bottom";

	// Reset so we can measure intrinsic size each call.
	content.style.left = "0px";
	content.style.top = "0px";
	content.style.removeProperty("--watch-club-popover-content-available-height");

	const a = anchor.getBoundingClientRect();
	const c = content.getBoundingClientRect();
	const margin = 8;

	const room = {
		top: a.top - margin,
		bottom: window.innerHeight - a.bottom - margin,
		left: a.left - margin,
		right: window.innerWidth - a.right - margin,
	};
	const needed = side === "top" || side === "bottom" ? c.height : c.width;
	if (
		room[side] < needed + sideOffset &&
		room[oppositeSide(side)] > room[side]
	) {
		side = oppositeSide(side);
	}

	let x = 0;
	let y = 0;
	if (side === "bottom" || side === "top") {
		y =
			side === "bottom" ? a.bottom + sideOffset : a.top - c.height - sideOffset;
		if (align === "start") x = a.left + alignOffset;
		else if (align === "end") x = a.right - c.width + alignOffset;
		else x = a.left + a.width / 2 - c.width / 2 + alignOffset;
	} else {
		x = side === "right" ? a.right + sideOffset : a.left - c.width - sideOffset;
		if (align === "start") y = a.top + alignOffset;
		else if (align === "end") y = a.bottom - c.height + alignOffset;
		else y = a.top + a.height / 2 - c.height / 2 + alignOffset;
	}

	x = Math.max(margin, Math.min(x, window.innerWidth - c.width - margin));
	y = Math.max(margin, Math.min(y, window.innerHeight - c.height - margin));

	content.style.left = `${x}px`;
	content.style.top = `${y}px`;
	content.setAttribute("data-side", side);
	content.setAttribute("data-align", align);
	content.style.setProperty(
		"--watch-club-popover-trigger-width",
		`${a.width}px`,
	);
	content.style.setProperty(
		"--watch-club-popover-content-transform-origin",
		transformOrigin(side, align),
	);

	// Available height for the content when stacked vertically. Consumers can
	// clamp `max-height` against this so the listbox never overflows.
	if (side === "bottom" || side === "top") {
		const available =
			side === "bottom"
				? window.innerHeight - a.bottom - sideOffset - margin
				: a.top - sideOffset - margin;
		content.style.setProperty(
			"--watch-club-popover-content-available-height",
			`${available}px`,
		);
	}
}
