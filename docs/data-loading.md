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

| Topic | Domain | Scope | Description | Triggered | Subscribers |
|---|---|---|---|---|---|
| `memberships:club:<club_id>` | Club Memberships | Club | Notifications about Club Memberships | `ClubMembership:CUD` | `/clubs/:club_id/members` |
| `users:admin` | Users | Admin | Notifications for admin about Users | `User:CUD`, `InvitationCode:CUD` | `/admin/users` |
| `users:admin` | Users | Admin | Notifications for admin about Users | `User:CUD`, `InvitationCode:CUD` | `/admin/users` |
| `user:<user_id>` | - | User | Notifications about Current User  | `User:U`, `UserSettings:U`, `ClubMembership:CUD` | Every page for current user |
| `club:<club_id>` | - | Club | Notifications about a Club  | `Club:U`, `Library:CUD` | Every page for current user (Sidebar) |
| `media_sources:admin` | MediaSources | Admin | Notifications about a a Media Source or Import  | `MediaSource:CUD`, `Import:CU` | `/admin/media_sources/*` |
| `content:user:<user_id>` | Contents | User | Notification about a Content that only affects a User | `ContentRequest:CUD`, `WatchProgress:CUD` | Any page that display content (Content Details, Club Library, Homepage...) |
| `content:club:<club_id>` | Contents | Club | Notification about a Content that affects members of a Club | `LibraryItem:CUD` | Any page that displays content (Content Details, Club Library...) |
| `content:global` | Contents | Global | Notification about a Content that affects everybody | `Media:CUD` | Any page that displays content (Content Details, Club Library, Homepage...) |
