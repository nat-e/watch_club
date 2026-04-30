// Hook for the <.carousel> component (lib/watch_club_web/components/ui/carousel.ex).
// Drives prev/next buttons by scrolling the viewport one slide-size at a
// time. Uses native scroll-snap, so the user can also swipe/scroll.
// Optional autoplay advances the carousel every N ms (paused on hover).

function vertical(el) {
	return el.getAttribute("data-orientation") === "vertical";
}

function step(track, direction) {
	const isVertical = vertical(track.parentElement.parentElement);
	const r = track.getBoundingClientRect();
	const size = isVertical ? r.height : r.width;
	const at = isVertical ? track.scrollTop : track.scrollLeft;
	const max = isVertical
		? track.scrollHeight - track.clientHeight
		: track.scrollWidth - track.clientWidth;
	const loop =
		track.parentElement.parentElement.getAttribute("data-loop") === "true";
	let target = at + direction * size;
	if (loop) {
		if (direction > 0 && at >= max - 1) target = 0;
		else if (direction < 0 && at <= 0) target = max;
	}
	if (isVertical) track.scrollTo({ top: target, behavior: "smooth" });
	else track.scrollTo({ left: target, behavior: "smooth" });
}

function setup() {
	this.track = this.el.querySelector('[data-slot="carousel-track"]');
	this.prev = this.el.querySelector('[data-slot="carousel-prev"]');
	this.next = this.el.querySelector('[data-slot="carousel-next"]');

	this.prev?.addEventListener("click", this.onPrev);
	this.next?.addEventListener("click", this.onNext);

	const delay = parseInt(this.el.getAttribute("data-autoplay"), 10);
	if (Number.isFinite(delay) && delay > 0) {
		this.autoplayDelay = delay;
		this.startAutoplay();
		this.el.addEventListener("mouseenter", this.onEnter);
		this.el.addEventListener("mouseleave", this.onLeave);
		this.el.addEventListener("focusin", this.onEnter);
		this.el.addEventListener("focusout", this.onLeave);
	}
}

function teardown() {
	this.prev?.removeEventListener("click", this.onPrev);
	this.next?.removeEventListener("click", this.onNext);
	this.el.removeEventListener("mouseenter", this.onEnter);
	this.el.removeEventListener("mouseleave", this.onLeave);
	this.el.removeEventListener("focusin", this.onEnter);
	this.el.removeEventListener("focusout", this.onLeave);
	this.stopAutoplay();
}

export const CarouselHook = {
	mounted() {
		this.onPrev = () => step(this.track, -1);
		this.onNext = () => step(this.track, 1);
		this.onEnter = () => this.stopAutoplay();
		this.onLeave = () => this.startAutoplay();
		this.startAutoplay = () => {
			if (this.autoplayDelay && !this.timer) {
				this.timer = setInterval(() => step(this.track, 1), this.autoplayDelay);
			}
		};
		this.stopAutoplay = () => {
			if (this.timer) {
				clearInterval(this.timer);
				this.timer = null;
			}
		};
		setup.call(this);
	},
	updated() {
		teardown.call(this);
		setup.call(this);
	},
	destroyed() {
		teardown.call(this);
	},
};
