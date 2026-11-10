# Chromecast

The Player casts to a Chromecast or a TV with Google Cast, and the Remote controls it from any device. `CONTEXT.md` has the rules of Playback Sessions, Screens and casting.

## Decisions

- **One receiver page for every instance.** Google Cast opens a Custom Web Receiver at the fixed address of a registered Cast app, and self-hosted instances can't each register one. WatchClub's receiver page, `cast_receiver/index.html`, holds nothing of an instance: the Player that casts sends it the instance's address and a token, and the page loads that instance's TV code, `/assets/js/tv.js`. The page stores nothing.
- **The TV talks to the instance, not to Chrome.** Chrome only launches the receiver. The TV joins its Playback Session over a socket (`WatchClubWeb.TvSocket` and `TvChannel`), plays what it's told, follows the Remote's commands and reports where it's at. So any signed-in device can be the Remote, iPhones included, and chat or watch parties can use the same path later.
- **Only Chrome on a computer or Android casts.** Google's Web Sender doesn't run elsewhere, and the Player offers casting only over HTTPS: the TV loads WatchClub from the address the Player was opened at, which must be HTTPS, reachable by the TV, with a trusted certificate.
- **Video files open with a token.** A TV has no login cookie, so a Playback's file URLs hold a signed token (`WatchClubWeb.Helpers.PlaybackPaths`) that works while the Playback is current, and any origin can read them. The Player uses the same URLs. The token is a `token` query parameter, which telemetry redacts, and every URI in the playlists repeats it, because players resolve them without the playlist's query.
- **The TV plays with Google's receiver framework (CAF).** It plays the same HLS as the Player, adapts the quality itself, and has no quality picker. It finds a Playback's audio by its order in the master playlist, which follows the file's stream order. It loads subtitles from their files instead of the master playlist: each video segment starts its own timeline, which CAF doesn't place the playlist's subtitles on.
- **Reports name their Playback.** The TV and the Player report positions, ends and track picks for a Playback, and the server rejects late reports about one that's no longer current.
- **Development uses an emulator.** `@mattiasbuelens/chromecast-emulator` opens the receiver page in a window, served by the dev server through dev-only routes. Real devices are only checked by hand, and through user reports.

## CI

There are two channels, each with its Cast app and its receiver page on GitHub Pages, kept in sync with the Docker image of the same channel:

| Channel | Cast app | Receiver page | Image | Built from |
| --- | --- | --- | --- | --- |
| release | `C95418C7`, published | `https://nat-e.github.io/watch_club/chromecast_receiver/` | `latest` | the latest release tag |
| edge | `8DEDC147`, published | `https://nat-e.github.io/watch_club/chromecast_receiver_edge/` | `edge` | `main` |

The `Cast receiver` workflow publishes both pages on every push to `main` that changes `cast_receiver/`, and on every release tag, because Pages hosts a single site. `ci.yml` builds release images with `CAST_RECEIVER=release`, and every other build casts with the edge app (`config/config.exs`). Local development casts to the emulator, whatever the app.

## Observability

Real TVs are only checked through what they report. The TV sends the errors of Google's receiver framework to the server: one that stopped the playback is logged as a `tv_playback_failed` error, which reaches Sentry, and the others, which it recovers from, as `tv_playback_error` warnings. `watch_club.cast.steps` counts each step of a cast by `watch_club.cast.result`: `started` when the Player hands the TV its token, then `joined`, `refused`, `failed` when the TV never joined within 20 seconds (also logged as a `cast_failed` warning), or `cancelled`, and `rejoined` or `left` as the TV's connection comes and goes. Many `started` without `joined` usually means the TV can't reach the instance over HTTPS. `watch_club.playback_session.endings` counts why Playback Sessions end, by `watch_club.playback_session.end_reason`: `stopped`, `nothing_next` or `abandoned`.

## Updating the receiver

The release page serves every instance, including those still on older releases, so a change to it must keep working with them: keep the `urn:x-cast:club.watch` namespace, its `{origin, token}` message, and `WatchClubTv.start(context, message)` and `WatchClubTv.stop()`. Most of the TV's code lives in `assets/js/tv.js`, which ships with each release and can change freely. Merge a change to the page, check it on a TV running an `edge` instance, and the next release publishes it. A change that would break older instances needs a new Cast app with its own page, which new releases then use, while the old app keeps the old page.

The Cast apps belong to the repository owner's account in the Google Cast SDK Developer Console, which publishes them, points them at their pages and registers test devices.
