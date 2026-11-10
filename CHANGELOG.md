# Changelog

## [0.1.6](https://github.com/nat-e/watch_club/compare/v0.1.5...v0.1.6) (2026-11-10)


### Features

* **player:** cast to a TV ([#77](https://github.com/nat-e/watch_club/issues/77)) ([71e7d89](https://github.com/nat-e/watch_club/commit/71e7d89fec82081642c3461b18ef7e76ff9b251f))

## [0.1.5](https://github.com/nat-e/watch_club/compare/v0.1.4...v0.1.5) (2026-11-10)


### Bug Fixes

* **telemetry:** keep reset tokens and Invitations out of telemetry ([#79](https://github.com/nat-e/watch_club/issues/79)) ([52b3a7b](https://github.com/nat-e/watch_club/commit/52b3a7bd69df066bd7bb7cc99ae0544cd4aa331a))


### Performance Improvements

* **contents:** refresh metadata by writing only what changed ([#78](https://github.com/nat-e/watch_club/issues/78)) ([6e8f0ed](https://github.com/nat-e/watch_club/commit/6e8f0ed422adb1f392bee48f12e32c95599935ba))

## [0.1.4](https://github.com/nat-e/watch_club/compare/v0.1.3...v0.1.4) (2026-11-09)


### Features

* **home:** restore Home with Up next, For You, Watching Now and the Activity Feed ([#76](https://github.com/nat-e/watch_club/issues/76)) ([8f36110](https://github.com/nat-e/watch_club/commit/8f361102fd8fbe1c2da0dd02eee0478c13c72fad))
* **media:** page through every Media in the Media Browser ([#74](https://github.com/nat-e/watch_club/issues/74)) ([2b0a536](https://github.com/nat-e/watch_club/commit/2b0a536347b9afddd6ad2498f35c0dc8599b6ddc))
* **player:** report a problem from the Player ([#75](https://github.com/nat-e/watch_club/issues/75)) ([12ae51c](https://github.com/nat-e/watch_club/commit/12ae51c68de01127b72f197b527d7c59e74ddea9))
* **player:** skip intros and play the next episode when the credits start ([#70](https://github.com/nat-e/watch_club/issues/70)) ([709a5d4](https://github.com/nat-e/watch_club/commit/709a5d4328bb3ccac5fa14f2e21724f028027c9e))


### Bug Fixes

* match filesystem movies that have no year in their file name ([#71](https://github.com/nat-e/watch_club/issues/71)) ([7e57dfd](https://github.com/nat-e/watch_club/commit/7e57dfd207efcb52cb92e25045e06b9100a136df))

## [0.1.3](https://github.com/nat-e/watch_club/compare/v0.1.2...v0.1.3) (2026-11-09)


### Features

* **contents:** download a Movie's or a TV Show Episode's original file ([#64](https://github.com/nat-e/watch_club/issues/64)) ([e88200c](https://github.com/nat-e/watch_club/commit/e88200c1f284b121d445dac93df25bcabcdda63c))
* restore audio and subtitle preferences ([#63](https://github.com/nat-e/watch_club/issues/63)) ([06a20b0](https://github.com/nat-e/watch_club/commit/06a20b0c07354aac08c7cc21c9c9b132e255d0f8))


### Bug Fixes

* index foreign keys for library queries ([#68](https://github.com/nat-e/watch_club/issues/68)) ([2765496](https://github.com/nat-e/watch_club/commit/27654962f8b75d37ddbfe2d13e8d8a9e27715c45))
* load the next page a screen before the end of infinite scroll lists ([#69](https://github.com/nat-e/watch_club/issues/69)) ([c514316](https://github.com/nat-e/watch_club/commit/c51431622f9e6d7e2f16f79b2a9605c3f8d4a023))
* **observability:** drop long-poll traces and tag socket metric by transport ([#67](https://github.com/nat-e/watch_club/issues/67)) ([8f9e300](https://github.com/nat-e/watch_club/commit/8f9e3002c1412da38cd31c44ed3e27245c8d21b0))

## [0.1.2](https://github.com/nat-e/watch_club/compare/v0.1.1...v0.1.2) (2026-11-09)


### Bug Fixes

* **contents:** store Content metadata and refresh it on page views and Media Imports ([#59](https://github.com/nat-e/watch_club/issues/59)) ([83a49cd](https://github.com/nat-e/watch_club/commit/83a49cd70a2c4f774d7df3a692cb5d1e3c4fb5c2))
* **observability:** correct metrics and reduce trace noise ([#62](https://github.com/nat-e/watch_club/issues/62)) ([b545fbd](https://github.com/nat-e/watch_club/commit/b545fbdd6a2f3f265c6880a0a090dbfcb7da8b84))
* **observability:** start the OTLP exporter before the SDKs in releases ([#61](https://github.com/nat-e/watch_club/issues/61)) ([7bc460c](https://github.com/nat-e/watch_club/commit/7bc460cb227b561151a0bba34beddbf5c04dd82c))
* **player:** play external subtitle files ([#58](https://github.com/nat-e/watch_club/issues/58)) ([38ae405](https://github.com/nat-e/watch_club/commit/38ae405e76499db4ecf22c0043c903ae9364df72))

## [0.1.1](https://github.com/nat-e/watch_club/compare/v0.1.0...v0.1.1) (2026-11-08)


### Features

* **observability:** add OpenTelemetry metrics, logs and traces ([#57](https://github.com/nat-e/watch_club/issues/57)) ([ce1a64b](https://github.com/nat-e/watch_club/commit/ce1a64b76749e7e072dc3be61499d5464b8e2cdd))


### Bug Fixes

* **media:** preserve subtitles with unknown codecs ([#55](https://github.com/nat-e/watch_club/issues/55)) ([f238c3d](https://github.com/nat-e/watch_club/commit/f238c3d4a81dce35cb801c8f50ad01c6c16ba9af))

## [0.1.0](https://github.com/nat-e/watch_club/compare/v0.1.0...v0.1.0) (2026-11-07)


### Features

* **auth:** return to the requested page after sign-in ([#34](https://github.com/nat-e/watch_club/issues/34)) ([f4745f3](https://github.com/nat-e/watch_club/commit/f4745f33ed8e818264e8d7a3ec3fd078a8e3b8dc))
* **browse:** filter and sort Browse ([#42](https://github.com/nat-e/watch_club/issues/42)) ([8e24ea9](https://github.com/nat-e/watch_club/commit/8e24ea9815fd0745b335871b0a37433a19b95efb))
* **browse:** filter Browse by genre ([#44](https://github.com/nat-e/watch_club/issues/44)) ([f19cfe2](https://github.com/nat-e/watch_club/commit/f19cfe2785ac40a01a5d8582bede3e669dd14b08))
* **browse:** replace Home with Browse and the new tabs ([#40](https://github.com/nat-e/watch_club/issues/40)) ([2a3cb26](https://github.com/nat-e/watch_club/commit/2a3cb266d57ba5801351d71b5942c32b60e4b872))
* **browse:** show ratings and filter Browse by them ([#45](https://github.com/nat-e/watch_club/issues/45)) ([19102da](https://github.com/nat-e/watch_club/commit/19102da4d23d4e16564cf48fdc9308d6302a0ec4))
* check the database in /health and report errors to Sentry ([#22](https://github.com/nat-e/watch_club/issues/22)) ([dc357a7](https://github.com/nat-e/watch_club/commit/dc357a7c95e262b6ea6de42b6101aaaf06211906))
* **contents:** replace the Movie and TV Show pages with one Content page ([#43](https://github.com/nat-e/watch_club/issues/43)) ([b5b0d76](https://github.com/nat-e/watch_club/commit/b5b0d764e3cd7440990693ccd10d23cf620fae61))
* **conversations:** recommend Content and talk about it in the Inbox ([#49](https://github.com/nat-e/watch_club/issues/49)) ([78546dc](https://github.com/nat-e/watch_club/commit/78546dcfe5c92ff96eaeb8d207657ed2cff253d3))
* hide books until they are supported ([#19](https://github.com/nat-e/watch_club/issues/19)) ([ff73fbf](https://github.com/nat-e/watch_club/commit/ff73fbfcf1da6c31f33124aada7a2115a1a4e847))
* **home:** spotlight, Up next and a grouped activity feed ([#31](https://github.com/nat-e/watch_club/issues/31)) ([40979ec](https://github.com/nat-e/watch_club/commit/40979ec6d1710dbfc73fc16378843f94c8152b73))
* **nav:** new app bar, phone tabs and search drop-down ([#35](https://github.com/nat-e/watch_club/issues/35)) ([f8f722c](https://github.com/nat-e/watch_club/commit/f8f722c301181ea819937457f9773137eb9e9549))
* **nav:** redesign the sidebar ([#32](https://github.com/nat-e/watch_club/issues/32)) ([b3a3dfe](https://github.com/nat-e/watch_club/commit/b3a3dfe1aef6b1bc56239bbe74208e6581ce6c42))
* **playlists:** turn lists into Playlists, with Share Playlist ([#48](https://github.com/nat-e/watch_club/issues/48)) ([6de5273](https://github.com/nat-e/watch_club/commit/6de52734ebf07d002a89e430ed3c71dfaa22518e))
* remove clubs ([#52](https://github.com/nat-e/watch_club/issues/52)) ([92dbadf](https://github.com/nat-e/watch_club/commit/92dbadf9f9fc742ef00a518f12ddae97a5870c97))
* **requests:** keep one Content Request per Content, with Get Notified ([#46](https://github.com/nat-e/watch_club/issues/46)) ([f6e3e0e](https://github.com/nat-e/watch_club/commit/f6e3e0e65495296703aabab9a9f4bc9c78d93bdc))
* **requests:** show Play, Request and request progress on Playlist Items and the Content page ([#54](https://github.com/nat-e/watch_club/issues/54)) ([9ff7af0](https://github.com/nat-e/watch_club/commit/9ff7af0355da75786c68e7f43caa199302013c4c))
* **requests:** show what's ready first on My Requests, with a badge ([#51](https://github.com/nat-e/watch_club/issues/51)) ([58e62bc](https://github.com/nat-e/watch_club/commit/58e62bccf4f8b9453816b65e3960adb4667fa940))
* **settings:** add the required TMDB attribution ([#24](https://github.com/nat-e/watch_club/issues/24)) ([69f5869](https://github.com/nat-e/watch_club/commit/69f586929d2078c85cdf7dfc54cbfd3718f5f37f))
* **ui:** apply Refactoring UI to the design system ([#30](https://github.com/nat-e/watch_club/issues/30)) ([19134b3](https://github.com/nat-e/watch_club/commit/19134b39919a186d9eeec5df8b4356dd63a7665b))


### Bug Fixes

* **deps:** update dependency ash_authentication to v4.15.1 [security] ([#38](https://github.com/nat-e/watch_club/issues/38)) ([190a8f3](https://github.com/nat-e/watch_club/commit/190a8f385aab41184bbbe951dba5f69a4e204d32))
* **i18n:** translate the remaining English text in French ([#21](https://github.com/nat-e/watch_club/issues/21)) ([0d9cb90](https://github.com/nat-e/watch_club/commit/0d9cb909976d943ec145337bc78a8e45684c0e64))
* make HTTPS work behind a TLS-terminating proxy ([#20](https://github.com/nat-e/watch_club/issues/20)) ([52a8f16](https://github.com/nat-e/watch_club/commit/52a8f16fa3254040d85c1bec6d98c09161d98875))
* make mix reset recreate the database ([c9eb38e](https://github.com/nat-e/watch_club/commit/c9eb38ea1864ccd1f7ba8e73526513a902d5b681))
* **player:** fail the segment cache cleanup instead of deleting live caches ([#23](https://github.com/nat-e/watch_club/issues/23)) ([e01bfb4](https://github.com/nat-e/watch_club/commit/e01bfb40b0553716d751125ac32e809aa7500d82))
* return an error for every 4xx response from TMDB ([#25](https://github.com/nat-e/watch_club/issues/25)) ([502cd93](https://github.com/nat-e/watch_club/commit/502cd9389a091de255ac37a0b6b3a5c5b15d11d2))
* show Servarr connection errors when adding or editing a source ([#26](https://github.com/nat-e/watch_club/issues/26)) ([3ec7a36](https://github.com/nat-e/watch_club/commit/3ec7a36c9e657eed74488439d91440d93948ccef))
* speed up Continue Watching for users with a long watch history ([#27](https://github.com/nat-e/watch_club/issues/27)) ([2b77cee](https://github.com/nat-e/watch_club/commit/2b77ceedf7776d6eb30b0f06d8c3179e147d432b))


### Miscellaneous Chores

* version releases as alpha until 1.0 ([ca6e3f5](https://github.com/nat-e/watch_club/commit/ca6e3f5b1a6d2cbee0bc0175ee19a530677b865e))
