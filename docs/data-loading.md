# Data Loading in the Phoenix WebApp

## Data Loading in LiveView

Data is loaded in `mount()` or in `handle_params()` when it depends on URL parameters
To keep code simple, ONLY EXPECTED ERRORS are handled
  - Data depends on user input or URL parameters we don't control
  - Data is loaded from an external API
Database failures or weird race conditions are not expected and it's ok to fail around those, no need to code defensively.
All data being loaded in the application should be subscribed to via PubSub and refresh in real time, whether the action was triggerred by the user locally, in a different component, tab, or another user completely.

## Mutations

### Forms

When user input is necessary, we use forms with `AshPhoenix.Form` to validate and submit the form.
Failed submissions should re-assign the form on the socket and the errors are displayed inline.

### Without user input

When there is no or very limited user input (e.g. a deletion confirmation modal), we call the mutation function directly.
For most cases, we prefer to call the bang version since those actions should not fail. It is better UX to gate actions which will fail in the UI before they are call.
Race conditions should be very rare, since all the data is reloaded through PubSub. It is not worth adding complexity to handle those rare occurrences.

### Reloading data

We do not patch or reload the data explicitely upon completion of a mutation. We rely on PubSub to reload it for us.

### External mutations

Mutations that are expected to fail (e.g. calling an external API), should often be scheduled through an Oban job so that they can be retried.

## PubSub

All PubSub messages are `%Phoenix.Socket.Broadcast{}` envelopes whose `payload` is an `Ash.Notifier.Notification`. Resources get this via the `WatchClub.PubSubDefaults` fragment; custom notifiers must wrap their notifications in the same envelope.
Subscribers pattern match on the envelope's `topic` rather than on the notification's resource.
We do not try to patch the existing data from the payload, instead we reload the data completely.

### PubSub topics

| Topic | Description | Triggered | Subscribers |
|---|---|---|---|
| `users` | Change regarding users | `User:register_with_password`, `User:destroy` | `/admin/users` |
| `users:<user_id>:settings` | Change regarding a User's settings | `UserSettings:update` | Every page for current user |
| `users:<user_id>:memberships` | Change regarding a User's memberships | `Membership:create`, `Membership:destroy` | Every page for current user |
| `clubs:<club_id>` | Change regarding a club (name) | `Club:update` | `/clubs/:club_id/*` |
| `clubs:<club_id>:libraries` | Change regarding a club libraries | `Library:create`, `Library:update`, `Library:destroy` | `/clubs/:club_id/settings` |
| `clubs:<club_id>:libraries:<library_id>` | Change regarding a single Club Library | `Library:update`, `Library:destroy` | `/clubs/:club_id/library/:library_id` |
| `clubs:<club_id>:memberships` | Change regarding club memberships | `Membership:create`, `Membership:destroy` | `/clubs/:club_id/members` |
| `media_sources` | Change regarding Media Source | `MediaSource:create`, `Membership:destroy` | Every page for current user |
| `content:<external_id_source>:<external_id>` | Change regarding a Content that affect everyone (refreshed Metadata, new Media, ...) | `Membership:create`, `Membership:destroy` | Every page that displays content |
| `content:<external_id_source>:<external_id>:user:<user_id>` | Change regarding a Content x User (ContentView) | `Membership:create`, `Membership:destroy` | Every page that displays content |