// Casting from the Player with Google Cast, in Chrome on a computer or an Android phone. The TV
// runs WatchClub's receiver page, in cast_receiver/, which connects to WatchClub itself: Chrome
// only launches it and passes it this instance's address and a token.

// Keep it as it is: the receiver page of every instance listens on it
const namespace = "urn:x-cast:club.watch";
const senderScript =
	"https://www.gstatic.com/cv/js/sender/v1/cast_sender.js?loadCastFramework=1";
// How long the TV has to take the Playback Session once Chrome connected to it
const connectTimeout = 20000;

let contextPromise;

const loadScript = (src, dataset = {}) =>
	new Promise((resolve, reject) => {
		const script = document.createElement("script");
		script.src = src;
		Object.assign(script.dataset, dataset);
		script.onload = resolve;
		script.onerror = reject;
		document.head.append(script);
	});

// Google's CastContext for the Cast app, or null where this browser can't cast: outside Chrome, or
// outside HTTPS, which the TV needs to load WatchClub. In development, the emulator stands in for
// the TV.
export const castContext = (appId, emulatorJson) => {
	contextPromise ??= (async () => {
		const emulator = emulatorJson && JSON.parse(emulatorJson);
		if (!window.chrome || !(emulator || window.location.protocol === "https:"))
			return null;

		if (emulator) {
			await loadScript(emulator.scripts[0]);
			await loadScript(emulator.scripts[1], {
				receiverUrl: emulator.receiver_url,
			});
		}
		const available = new Promise((resolve) => {
			window.__onGCastApiAvailable = resolve;
		});
		await loadScript(senderScript);
		if (!(await available)) return null;

		const context = cast.framework.CastContext.getInstance();
		context.setOptions({
			receiverApplicationId: appId,
			autoJoinPolicy: chrome.cast.AutoJoinPolicy.ORIGIN_SCOPED,
		});
		return context;
	})().catch(() => null);

	return contextPromise;
};

// Connects Chrome to the TV the User picks in its list, then sends the TV what it needs to take
// the Playback Session. Gives up after a while: the TV may not reach this address. Resolves with
// `cancel`, which stops casting, and `dispose`, for once the TV took over; or nothing when the
// User closed the list.
export const startCasting = async (
	appId,
	emulatorJson,
	{ beforeLaunch, token, onFailure },
) => {
	const context = await castContext(appId, emulatorJson);
	try {
		if (!context.getCurrentSession()) await context.requestSession();
	} catch (_closed) {
		return undefined;
	}

	const session = context.getCurrentSession();
	beforeLaunch();
	const tvToken = await token(session.getCastDevice().friendlyName);
	session.sendMessage(namespace, {
		origin: window.location.origin,
		token: tvToken,
	});

	const timer = setTimeout(() => {
		session.endSession(true);
		onFailure();
	}, connectTimeout);

	return {
		cancel: () => {
			clearTimeout(timer);
			session.endSession(true);
		},
		dispose: () => clearTimeout(timer),
	};
};
