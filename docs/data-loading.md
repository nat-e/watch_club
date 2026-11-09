# Data Loading in the Phoenix WebApp

## Data Loading in LiveView

Data is loaded in `mount()` or in `handle_params()` when it depends on URL parameters
To keep code simple, ONLY EXPECTED ERRORS that can be fixed are handled
  - Data depends on user input or URL parameters we don't control
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
This has the benefit of using the same code path for any update to the data. We might introduce optimistic update later if it feels laggy.

### External mutations

Mutations that are expected to fail (e.g. calling an external API), should often be scheduled through an Oban job so that they can be retried.

## PubSub

All PubSub messages are `%Ash.Notifier.Notification{}`.
Our topics are voluntarily coarse, and are mainly built around the `scope` of the change, which represents the user of group of users affected by the change, sometimes prefixed by a `domain`.
The idea is to reduce complexity in managing the PubSub topic subscriptions by only having a few topics and pattern matching on the Notification resource / action type to figure out how to process it.
It is OK if not all events are relevant in a subscribed topic. As a self-hosted product, we expect a low number of users per instance.

Data can be upated directly from the Notification payload if straight forward. If not, we prefer to reload the data entirely rather than introduce too much complexity.

### PubSub topics

| Topic | Domain | Scope | Description | Triggered | Subscribers |
|---|---|---|---|---|---|
| `users:admin` | Users | Admin | Notifications for admin about Users | `User:CUD`, `InvitationCode:CUD` | `/admin/users` |
| `user:<user_id>` | - | User | Notifications about Current User  | `User:U`, `UserSettings:U`, `Participant:C` (a new Conversation), `Participant:U` (read), `RequestSubscriber:U` (ready unseen), `Playlist:C` (owner), `PlaylistAccess:CD`, `PlaylistAccess:U` (shared unseen) | Every page for current user |
| `playlist:<playlist_id>` | Playlists | Playlist | Notifications about a Playlist, for everyone who sees it | `Playlist:UD`, `PlaylistItem:CD` | `/playlists`, `/movies/:tmdb_id`, `/shows/:tmdb_id`: each subscribes to the Playlists it loads |
| `media_sources:admin` | MediaSources | Admin | Notifications about a a Media Source or Import  | `MediaSource:CUD`, `Import:CU` | `/admin/media_sources/*` |
| `content:user:<user_id>` | Contents | User | Notification about a Content that only affects a User | `RequestSubscriber:CD`, `WatchProgress:CUD` | Any page that display content (Content page, Browse...) |
| `content:global` | Contents | Global | Notification about a Content that affects everybody | `ContentRequest:CUD`, `Media:CUD`, `Content:CUD` | Any page that displays content (Content page, Browse...) |
| `history:global` | History | Global | Every User's Watch Progress, for the Watchers of a Content | `WatchProgress:CD` | `/movies/:tmdb_id`, `/shows/:tmdb_id` |
| `conversation:<conversation_id>` | Conversations | Conversation | A Message posted in a Conversation | `Message:C` | Every page of its Participants, subscribed to all their Conversations |
| `feed:global` | ActivityFeed | Global | A Feed Event joined or left a Feed Entry | `ContentWatchedEvent:CD` | `/` (Home) |
| `video:<video_id>` | Markers | Video | The Markers of a Video, found in the background after its import | `Marker:CD` | `/play/:media_id`, subscribed to each Video it plays |


## LiveComponents

To provide a better separation of concern, some complex interactive components (PlayOrRequestButton, ...) are extracted to `LiveComponents` that handle their own data loading and mutation.
For these, data loading is performed in `update_many()` in order to avoir N+1 queries in lists.
They cannot directly receive PubSub event since they share the same process as the LiveView that host them, but they provide a `handle_pubsub_message()` function to collocate notification handling and make it easy for the host LiveViews to deal with.

## Error handling

Handling errors and corner cases is a huge source of complexity in code. Most often than not, developers tend to be too defensive and handle errors without providing much value to the user.

We follow the "let it crash" Elixir mantra. We believe there is no point in adding code complexity to handle errors unless they are **expected** and can be **acted upon**.

- **In LiveView**: In production, crashing the LiveView will simply reload the page. This can act as a retry with a clear state and can actually fix the issue more often than not. Even if it doesn't, this is not a much worse user experience than a useless generic flash message like `Something went wrong`.
Also, crashing processes will show us debuggable errors for free.

- **In Oban Jobs**: Oban by nature already takes care of re-scheduling failed jobs, and will display actionable errors when the process crashes. There is no value in handling errors (unless they are not fatal and the job should actually continue).