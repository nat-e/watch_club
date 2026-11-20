---
name: port-feature
description: "Rewrite a feature of the Phoenix app in this stack: learn what it does from the Phoenix code, then build it the simplest idiomatic way on the server, the web app and the mobile app. Use when the user asks to port, rewrite or bring over a feature from the Phoenix app."
---

Port the feature the user names from the Phoenix app, `~/dev/watch_club`, a checkout of `main`, to the server, the web app and the mobile app.

The Phoenix app shows what the feature does for Users: what they see and do, its rules, its data and its texts. It doesn't show how to build it here. The goal is to re-design and build the feature from scratch, focusing on clean, scalable and maintainable code using idiomatic solutions in Rust, Axum, React and Expo.
UX and behavior should be considered a starting point, but cutting things that brings significant complexity should be favored.
Start simple, with defaults implementations and behaviors, and only customize if not satisfactory.

## Research

Run one more exploration subagent on the Phoenix app, the current code, and idiomatic/recommended ways to solve the problem.

Then grill the user, in order to present a design for the implementation.

## Decisions

These defaults are settled:

- No live updates, such as PubSub broadcasts or LiveView pushes, unless the user asks. Screens fetch their data when they open and after the User's own changes.
- The web app keeps Phoenix's screens, with their layout and information. The mobile app adapts them to what's idiomatic on phones and TVs, and leaves out administration pages. No particular effort is put into mobile web. It will reuse desktop layout with low-effort CSS responsiveness to make it acceptable.
- How Phoenix handles a corner case doesn't bind the port: drop it, or handle it more simply, when that makes the code much simpler.
