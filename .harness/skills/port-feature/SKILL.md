---
name: port-feature
description: "Rewrite a feature of the Phoenix app in this stack: learn what it does from the Phoenix code, then build it the simplest idiomatic way on the server, the web app and the mobile app. Use when the user asks to port, rewrite or bring over a feature from the Phoenix app."
---

Port the feature the user names from the Phoenix app, `~/dev/watch_club`, a checkout of `main`, to the server, the web app and the mobile app.

The Phoenix app shows what the feature does for Users: what they see and do, its rules, its data and its texts. It doesn't show how to build it here. Ash resources, policies and changes, and LiveView assigns and streams, have no counterpart in this stack, and copying their shape adds complexity. Design the feature from first principles, as a seasoned axum, SQLx, React and Expo developer would. When matching Phoenix conflicts with keeping the code simple, choose simplicity.

Follow the `implement` skill, with these changes.

## Research

Before the `implement` skill's searches, run one more exploration subagent on the Phoenix app with the same settings. Ask it to describe the feature rather than its code, citing the files:

- the screens, and what Users see and do on each
- the rules, including who may do what
- the data it stores, and its jobs
- the corner cases it handles, and how
- its live updates

Point it to the feature's doc in `docs/`, and to its prototype in `dev/prototypes/`, whose doc comments record the design decisions and rejected alternatives. Git ignores `dev/prototypes/`, so `rg` searches it only when given its path.

Give the description to the `implement` skill's searches, so they look for how to build that behavior here.

## Decisions

These defaults are settled:

- No live updates, such as PubSub broadcasts or LiveView pushes, unless the user asks. Screens fetch their data when they open and after the User's own changes.
- Keep Phoenix's database schema, and change it where that makes it cleaner or more idiomatic: the data stays easy to migrate.
- The web app keeps Phoenix's screens, with their layout and information. The mobile app adapts them to what's idiomatic on phones and TVs, and leaves out administration pages.
- How Phoenix handles a corner case doesn't bind the port: drop it, or handle it more simply, when that makes the code much simpler.

## Plan

Add to the plan:

- What the port drops or changes compared with Phoenix's behavior and schema, so the user can object.
- How the mobile app adapts Phoenix's screens, in a few lines: no prototype shows it.
