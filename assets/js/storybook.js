import { hooks as colocatedHooks } from "phoenix-colocated/watch_club";
import componentsHooks from "./components";

(() => {
	window.storybook = { Hooks: { ...colocatedHooks, ...componentsHooks } };
})();

// Mirror theme + color-mode classes from `.psb-sandbox` onto `<body>`.
//
// Phoenix Storybook scopes theme variables (`--popover`, `--shadow-md`, …)
// to the `.psb-sandbox` container so the sidebar / chrome aren't themed.
// But popover-style overlays (select, dropdown_menu, popover, …) portal
// their floating content to `<body>` to escape transformed ancestors —
// landing them outside the sandbox, where the theme variables are unset.
// Mirroring the active theme/color-mode classes onto `<body>` makes the
// vars resolve at the document root, so portaled content inherits them
// without the components needing any storybook-specific code.
(function mirrorThemeToBody() {
	const THEME_RE = /^theme-/;
	const isTheme = (c) => THEME_RE.test(c) || c === "light" || c === "dark";

	function sync() {
		const sandbox = document.querySelector(".psb-sandbox");
		if (!sandbox) return;
		const want = new Set(Array.from(sandbox.classList).filter(isTheme));
		const have = new Set(Array.from(document.body.classList).filter(isTheme));
		have.forEach((c) => {
			if (!want.has(c)) document.body.classList.remove(c);
		});
		want.forEach((c) => {
			if (!have.has(c)) document.body.classList.add(c);
		});
	}

	function start() {
		sync();
		new MutationObserver(sync).observe(document.documentElement, {
			subtree: true,
			attributes: true,
			attributeFilter: ["class"],
		});
	}

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", start, { once: true });
	} else {
		start();
	}
})();
