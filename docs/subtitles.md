# Subtitles

The goal of Watch Club is to present the subtitles to the user in a user-friendly, understandable way, with sensible opinionated defaults, not to be exhaustive.

Glossary:
**Forced track**: A subtitle track that only contains subtitles for audio in a different language or annotations.
**SDH track**: A track that includes notes for non-dialog audio (music playing, noise that influences the plot), to help people with hearing deficiencies.

We only display one track per supported language (English, French or original), named English, French or {Original Language} in the subtitles track list. When a language has tracks for several regions, we display one per region, named {Language} ({Region}), such as French (France) and French (Canada). When tracks can't be told apart, we pick the first one.

When the `Prefer Subtitles for the Deaf and Hard of Hearing` option is checked in the User Settings, we prefer an SDH track for each language when available. Otherwise, we prefer a regular track and fall back to an SDH one. SDH tracks show an SDH icon.

Forced tracks are never shown in the list. When no subtitles are selected, we display a forced track in the user's preferred subtitle language, otherwise in the audio's language. If there is none, no subtitles are displayed.

Picture based subtitles tracks are hidden and not supported.

## Import

Subtitle tracks metadata is extracted at import time and stored in the database.
Since Forced and SDH markers are often not accurate, we also extract them, with the language and region, from the name of the file/track.
A track marked forced is a full track when its name says so ("Full", "Complet"). Otherwise, it is full with at least 5 lines per minute of the video, when the file counts its lines (mkvmerge writes the count), or else when its language matches none of the video's audio tracks.
All tracks metadata is stored in the database, and filtered later, so that adding or removing a language does not need re-importing.

## Future improvements

- Bazarr integration
- Download on demand / report auto-resolution
- AI generated subtitles?
