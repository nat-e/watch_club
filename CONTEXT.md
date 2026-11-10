# WatchClub

WatchClub is a self-hosted, private, invite-only media server where people can watch and discuss content. Discovery is curated by other people's recommendations, and it invites users to engage about the content. They can also request missing content directly from the application.

## Language

### Accounts

**User**:
A person with a WatchClub account.
_Avoid_: Account, profile

**Username**:
A user’s unique public name in WatchClub.
_Avoid_: Handle, display name

**Locale**:
A language and country preference.
_Avoid_: Language, region

**User Preferences**:
A user’s personal choices that shape their WatchClub experience.
_Avoid_: User settings, account settings

**Track Language**:
A language a **User** can choose for audio and subtitles: English or French.
_Avoid_: Locale

**Preferred Audio Language**:
The language a **User** wants to hear: the original language of the **Content**, or a **Track Language**.
_Avoid_: Default audio, audio setting

**Preferred Subtitle Language**:
The **Track Language** a **User** wants subtitles in, or none.
_Avoid_: Default subtitles, caption language

**Languages Without Subtitles**:
The audio languages a **User** watches without subtitles.
_Avoid_: Hidden subtitle languages, understood languages

**Instance Administrator**:
The single user who administers the WatchClub instance.
_Avoid_: Administrator, admin, owner

**Invitation**:
An instance-wide link created by the **Instance Administrator** that lets new people register. Redeemable only while it is not **Expired**, not **Disabled**, and not **Used**.
_Avoid_: Invite, invitation code

**Max Uses**:
The optional maximum number of new accounts an **Invitation** can create. Unlimited when unset.
_Avoid_: Use limit, seats, quota

**Redeem Invitation**:
A new person registers through an **Invitation**, creating their **User**. Counts as one use against the **Max Uses**.
_Avoid_: Accept invitation, join instance

**Expired Invitation**:
An invitation that can no longer be redeemed because its redemption window has passed.
_Avoid_: Invalid invitation, stale invitation

**Used Invitation**:
An invitation that has reached its **Max Uses** and can no longer be redeemed.
_Avoid_: Exhausted invitation, used-up invitation, spent invitation

**Disable Invitation**:
Deactivate a still-redeemable **Invitation** so its link can no longer be redeemed, without removing the **Users** it already created. Cannot be applied to a **Used Invitation**.
_Avoid_: Delete invitation, revoke invitation, cancel invitation, archive invitation

### Playlists

**Playlist**:
A named collection of **Content** owned by one **User**, private until they share it with other **Users**.
_Avoid_: List, shelf, watchlist

**Playlist Item**:
One **Content** in a **Playlist**, with who added it and when.
_Avoid_: Entry, track

**Add to Playlist**:
Put a **Content** in one or more **Playlists**.
_Avoid_: Save, bookmark

**Remove from Playlist**:
Take a **Content** out of a **Playlist** without deleting the **Content**.
_Avoid_: Delete from playlist

**Share Playlist**:
The owner of a **Playlist** gives one or more **Users** **Playlist Access** to it.
_Avoid_: Invite to playlist, collaborate

**Playlist Access**:
What a **User** can do with a **Playlist** shared with them: View it, or Edit it to also add and remove **Content**.
_Avoid_: Permission, role, viewer, editor, collaborator

**Shared Unseen**:
A **Playlist** shared with a **User** since they last opened their Playlists. The Playlists tab's badge counts them, and their Playlists show them first, with a New badge, until the **User** leaves them.
_Avoid_: Unread, notification, new playlist

### Conversations

**Recommend Content**:
A **User** sends one **Content** to one or more other **Users**, which starts a **Conversation** with them.
_Avoid_: Share content, send, suggest

**Conversation**:
The **Messages** about one **Content** between the **User** who recommended it and the **Users** they recommended it to.
_Avoid_: Chat, thread

**Participant**:
A **User** in a **Conversation**.
_Avoid_: Member

**Message**:
Something a **Participant** posts in a **Conversation**: the recommendation that starts it, or text.
_Avoid_: Reply, chat message, note

**Inbox**:
The WatchClub interface where a **User** sees their **Conversations**.
_Avoid_: Messages, chats

### Requests

**Content Request**:
A user’s request for WatchClub to make a piece of content available on the media server for everybody.
_Avoid_: Media Request, Request Media, download request, fetch request, acquisition request

**Content Request Status**:
The status of a **Content Request** as shown on **My Requests**, derived when read from whether it is a **Completed Content Request**, the **Content**'s **Media** and its **Media Source Requests**. One of: Not Released, Not Found, Searching, Downloading, Importing, Completed, Failed. It says how far the **Content Request** got, not whether its **Content** is **Ready to Play**. _Importing_ means a **Media Source** reports the file downloaded but its **Media** has not yet been ingested into WatchClub, so a request never shows Completed until **Media** exists. _Searching_ is the label for a just-submitted request still within its grace window, whose **Media Source** call is still in flight, or with no **Media Source** to request it from.
_Avoid_: Pending, Requested, Available, request state, Media Source Request State

**Completed Content Request**:
A **Content Request** whose **Content** has had **Media** for every aired part: the **Movie** or **Book**, or every aired **TV Show Episode**. It stays Completed, even when new **TV Show Episodes** air or its **Media** is deleted.
_Avoid_: Fulfilled, fully downloaded, available, ready, playable

**Media Source Request**:
WatchClub's record of asking one **Media Source** to make one **Content** available. Singleton per (**Content**, **Media Source**) pair. Only **Media Sources** whose **Media Source Type** supports requests can be the **Media Source** of a **Media Source Request**. In practice, referred to by the **Media Source Type**, e.g. "Radarr Request", "Sonarr Request".
_Avoid_: Request Attempt, Profile Request, Sourcing

**Media Source Request State**:
The progress of a **Media Source Request** in its **Media Source**, recorded on the **Media Source Request** itself and _reconciled from the **Media Source**'s current state_ (not driven by individual events). One of: Submitted, Not Released, Downloading, Downloaded, Needs Attention.
_Avoid_: Request Attempt State, *arr status, Grabbed, Searching, Cancelled, Created

**Request Content**:
A user creates a **Content Request** for one piece of **Content** so its media file is brought to the media server for everybody.
_Avoid_: Request media, fetch content, grab content, add to my downloads, add to watchlist

**Get Notified**:
A **User** becomes a **Request Subscriber** of a **Content Request**. Outside **My Requests**, it shows as Request, the same as **Request Content**.
_Avoid_: Follow, watch, me too

**Stop Getting Notified**:
A **Request Subscriber** stops being one, so the **Content Request** leaves their **My Requests**.
_Avoid_: Unsubscribe, unfollow, mute

**Request Subscriber**:
A **User** who is told when a **Content Request** is Completed: the **User** who made it, and everyone who chose to **Get Notified** on it, until they **Stop Getting Notified**.
_Avoid_: Follower

**Ready Unseen**:
A **Content Request** Completed since its **Request Subscriber** last opened **My Requests**. The Requests tab's badge counts them, and **My Requests** shows them first, with a New badge, until the **Request Subscriber** leaves it.
_Avoid_: Unread, notification

**Delete Content Request**:
The **Instance Administrator** removes a **Content Request**, for example a stuck one, so its **Content** can be requested again.
_Avoid_: Cancel request, unrequest

**My Requests**:
The WatchClub interface where a **User** views the **Content Requests** they are a **Request Subscriber** of: the Completed ones ready to watch, and the others on the way.
_Avoid_: My downloads, watchlist, request inbox

### Media

**Media**:
An instance-wide local file available in WatchClub as a video, ebook, or audiobook.
_Avoid_: Content, Media Version, media item

**Unmatched Media**:
Media whose concrete video, ebook, or audiobook has no attached **Content** because the **Media Import** could not identify it.
_Avoid_: Orphan media, unattached media, unidentified media

**Media Type**:
The kind of media, one of **Movie**, **TV Show Episode**, **Ebook**, or **Audiobook**. A Media Type determines both the concrete media kind (video, ebook, audiobook) and the **Content Type** the media is expected to attach to.
_Avoid_: Content Type, file type

**Video**:
Media that can be played and is attached to a movie or TV show episode.
_Avoid_: Media Version, video version

**Player**:
The WatchClub interface where a **User** watches a selected video.
_Avoid_: Video player page, stream page

**Play**:
Play available **Media** through WatchClub.
_Avoid_: Stream, watch media, play media server item

**Ready to Play**:
A **Content** a **User** can **Play** now: a **Movie** with **Media**, or a **TV Show** whose **TV Show Episode** they're up to has **Media**, the first one if they haven't started it.
_Avoid_: Playable, available, ready

**Download**:
Save a **Video**, **Ebook**, or **Audiobook** to the **User**'s device through WatchClub.
_Avoid_: Save offline, download media server item

**TV**:
A screen with Google Cast, such as a Chromecast or a Google TV, that plays **Videos** from WatchClub for a **User**.
_Avoid_: Chromecast, receiver, cast device

**Cast**:
Move a **Playback Session** from the **Player** to a **TV**, which goes on playing it there.
_Avoid_: Stream to TV, mirror, beam, Chromecast (as a verb)

**Remote**:
The WatchClub interface where a **User** controls the **Playback Session** playing on their **TV**.
_Avoid_: Controller, companion, expanded controller, mini controller

**Stop Casting**:
End the **Playback Session** playing on a **TV**.
_Avoid_: Disconnect, stop on TV, end cast

**Playback Session**:
What a **User** is watching right now, on whichever **Screen** it plays: its current **Playback**, where it's at, and the audio and subtitles picked. It belongs to the **User**, not to a device.
_Avoid_: Player Session, HLS Session, stream session, watch session, watch history, cast session

**Watching Now**:
A **User** whose **Playback Session** plays on a **Screen** right now, with the **Movie** or **TV Show Episode** it plays.
_Avoid_: Live, online, now playing, streaming

**Playback**:
One **Media** being played by a user inside a **Playback Session**.
_Avoid_: Stream, HLS Stream, play, playthrough

**Screen**:
Where a **Playback Session** plays right now: a **Player** or a **TV**.
_Avoid_: Device, output, display, receiver

**Watch Progress**:
How far a **User** has got through one **Movie** or one **TV Show Episode**, and whether they have finished it. Tied to the watchable work, not to a specific **Media**, so the several **Videos** that back one **Movie** or **Episode** share a single Watch Progress. Covers video only for now; reading a **Book** or listening to an **Audiobook** would be sibling concepts, not the same record.
_Avoid_: watch history, watch session, resume point, playhead, watched flag

**Watcher**:
A **User** with **Watch Progress** on a **Movie** or a **TV Show**: they watched it or are watching it.
_Avoid_: Viewer, audience

**Problem Report**:
What a **User** reports from the **Player** about the **Video** they're playing: what's wrong, an optional comment, and what the **Player** showed at that moment.
_Avoid_: Feedback, issue, bug report, ticket

**Report a Problem**:
Send a **Problem Report** to the **Instance Administrator** from the **Player**.
_Avoid_: Send feedback, flag, report an issue

**Archive a Problem Report**:
The **Instance Administrator** sets a handled **Problem Report** aside, without telling its **User**.
_Avoid_: Resolve, close, dismiss

**Ebook**:
Media that can be read or downloaded and is attached to a book.
_Avoid_: Media Version, digital book copy

**Audiobook**:
Media that can be played and is attached to a book.
_Avoid_: Media Version, audio media version

**Video Track**:
A persisted visual stream within a video.
_Avoid_: Stream metadata, playback option

**Default Video Track**:
The **Video Track** the **Player** uses for a **Video** and that the playback quality ladder is derived from.
_Avoid_: Primary video stream, main track

**Audio Track**:
A persisted audio stream within a video.
_Avoid_: Stream metadata, playback option

**Text Track**:
A persisted subtitle or caption track for a video.
_Avoid_: Subtitle track, caption track, stream metadata

**Forced Text Track**:
A **Text Track** that only translates what the audio's language doesn't cover, such as signs or lines in another language.
_Avoid_: Forced subtitles, foreign parts subtitles

**Preferred Audio Track**:
The **Audio Track** a **Playback** of new **Content** starts with, chosen from its **User**'s **User Preferences**.
_Avoid_: Default audio track, selected audio

**Preferred Text Track**:
The **Text Track** a **Playback** of new **Content** starts with, chosen from its **User**'s **User Preferences**, or none.
_Avoid_: Default subtitles, selected subtitles

**Media Browser**:
The WatchClub interface where the **Instance Administrator** inspects instance-wide **Media**, including **Unmatched Media**.
_Avoid_: Media admin, media library page, file browser

**Media Source**:
A reusable, instance-wide configuration of where WatchClub brings **Media** from, and optionally where it can ask for **Content** to be made available. A **Media Source** has exactly one **Media Source Type** and one **Media Type**. Depending on its **Media Source Type**, a **Media Source** may also accept **Media Source Requests**.
_Avoid_: Media Import Configuration, Media Library, Media Provider, Automation Service, Request Profile, playback source, streaming source, sync source

**Media Source Type**:
The kind of upstream system a **Media Source** represents. One of `filesystem`, `radarr`, or `sonarr` (with `chaptarr` planned but not yet implemented). A **Media Source Type** determines whether the **Media Source** accepts **Media Source Requests**: `filesystem` does not; `radarr` and `sonarr` do, as will `chaptarr`.
_Avoid_: Media Import Source Type, source kind, provider type

**Media Import**:
One execution of a **Media Source**'s scan-and-ingest cycle. A **Media Import** records the scan phase (started, finished, what it discovered) and is the umbrella for the per-file ingest work it enqueues. A webhook-triggered single-file ingest is not a **Media Import**.
_Avoid_: Media Source Import, Import Run, Media Scan Run, scan job, scan execution, sync

**Refresh Metadata**:
A **Media Import** option that re-evaluates existing **Media** instead of skipping it. A webhook-triggered single-file ingest always behaves as if **Refresh Metadata** were on.
_Avoid_: Force refresh, rescan existing media

**Media Import Status**:
The overall progress or outcome of a **Media Import**.
_Avoid_: import summary, run result, scan result

**Cancel Media Import**:
End an in-progress **Media Import** before its scan phase finishes; in-flight per-file ingest jobs continue to completion.
_Avoid_: Stop media import, abort scan, kill import

### Markers

**Marker**:
A part of a **Video** that the **Player** lets a **User** skip: its **Intro**, its **Recap** or its **Credits**.
_Avoid_: Segment, media segment, chapter, skip range

**Intro**:
The opening sequence, with the theme and the title, that the **TV Show Episodes** of a **TV Show** share.
_Avoid_: Opening, title sequence, opening credits

**Recap**:
The summary of earlier **TV Show Episodes** at the start of a **TV Show Episode**.
_Avoid_: Previously on, summary

**Credits**:
The list of names at the end of a **Video**.
_Avoid_: Outro, ending, end credits, end titles

### Contents

**Content**:
A creative work, such as a movie, TV show, or book.
_Avoid_: Media, title, item, recommendation

**Content Type**:
The kind of content, such as movie, TV show, or book.
_Avoid_: Media type, category

**Movie**:
Content whose content type is movie.
_Avoid_: Film

**TV Show**:
Content whose content type is TV show.
_Avoid_: Show, series

**TV Show Episode**:
A numbered part of TV show content.
_Avoid_: Episode, TV media, show item

**TV Show Episode Localization**:
A TV Show Episode's title and overview adapted for a Locale.
_Avoid_: Episode translation, localized episode

**Book**:
Content whose content type is book.
_Avoid_: Volume

**Metadata Provider**:
A catalog where content metadata comes from, such as TMDB or Hardcover.
_Avoid_: External source, provider, integration, source

**External ID**:
The identifier of content within one metadata provider.
_Avoid_: Provider ID, remote ID

**Content Localization**:
Content metadata adapted for a language and country.
_Avoid_: Localization, translation, localized content

**Preferred Content Localization**:
The content localization selected for a user based on their preferred locale.
_Avoid_: Best localization, current localization

**Genre**:
A kind of story a **Movie** or **TV Show** tells, such as Drama or Comedy.
_Avoid_: Category, tag

**Rating**:
How good people found a **Movie** or **TV Show**: the average of their votes out of 10 on its **Metadata Provider**.
_Avoid_: Score, vote average, grade

**Library**:
All the **Content** that is available on the **Instance** and has **Media**.
_Avoid_: Catalog, available content, server content

**Incomplete TV Show**:
A **TV Show** in the **Library** with an aired **TV Show Episode** that has no **Media**.
_Avoid_: Partially available, still downloading, partial

**Browse**:
The WatchClub interface where a **User** looks through the **Library**.
_Avoid_: Discover

### Home

**Home**:
The WatchClub interface that opens after signing in, where a **User** sees what's up next for them and what is happening in WatchClub.
_Avoid_: Dashboard, landing page, feed

**For You**:
What was addressed to one **User** lately, on **Home**: the recommendations to them, their **Content Requests** that were Completed and the **Playlists** shared with them.
_Avoid_: Notifications, alerts, inbox

### Activity Feed

**Activity Feed**:
What a **User** can see of what **Users** do in WatchClub, newest first.
_Avoid_: Timeline, news feed, event log

**Feed Event**:
One thing a **User** did that shows in an activity feed: watching or having watched **Content**.
_Avoid_: Activity, notification, action

**Feed Entry**:
One line of an activity feed: the **Feed Events** of one **User** doing the same thing, grouped together.
_Avoid_: Group, aggregate, card, item

## Relationships

### Accounts

- A **User** has exactly one **Username**
- There is at most one **Instance Administrator**
- A **User** has one set of **User Preferences**
- **User Preferences** belong to one **User** and are managed only by that **User**
- **User Preferences** include the user’s preferred **Locale**
- **User Preferences** include the user’s **Preferred Audio Language**, **Preferred Subtitle Language** and **Languages Without Subtitles**
- A new **User** gets subtitles in the language of their **Locale**, except when the audio is already in it
- Deleting a **User** does not delete their **Playback Sessions** or **Playbacks**
- Every **User** can see every other **User**
- An **Invitation** is the only way a new person joins WatchClub
- An **Invitation** is created and managed only by the **Instance Administrator**
- An **Invitation** is link-based and is not tied to any **User** before redemption
- An **Invitation** is redeemed only by a new person registering; an existing **User** can never redeem one
- **Redeem Invitation** creates the new **User** and counts as one use against the **Max Uses**
- An **Invitation** records its **Max Uses** and its use count, incremented each time it is redeemed
- An **Expired Invitation**, a **Disabled** **Invitation**, and a **Used Invitation** cannot be redeemed
- **Disable Invitation** can be applied at any time except to a **Used Invitation**, and leaves already-created **Users** intact

### Playlists

- A **Playlist** is owned by exactly one **User**
- A **User** can own any number of **Playlists**
- A **Playlist** has a name and an icon, both chosen by its owner
- A new **User** starts with one **Playlist**, named To Watch, which they can edit, share or delete like any other
- A **Playlist** is private: only its owner sees it until they **Share Playlist**
- **Share Playlist** gives each chosen **User** View or Edit **Playlist Access**
- A **User** with View access sees the **Playlist**; with Edit access they can also **Add to Playlist** and **Remove from Playlist**
- Only the owner can **Share Playlist**, change or remove a **User**'s **Playlist Access**, change the **Playlist**'s name or icon, or delete it
- Everyone with **Playlist Access** sees who else has it
- A **Playlist** has zero or more **Playlist Items**, shown newest added first
- A **Playlist** can contain a given **Content** at most once
- A **Playlist Item** records the **User** who added it
- A **Playlist Item** stays in its **Playlist** when the **User** who added it loses their **Playlist Access** or is deleted
- A **Playlist** can mix **Content Types**
- A **Playlist** holds whole **Content**: for a **TV Show**, the entire show, never a **TV Show Episode**
- A **Playlist** can hold **Content** that is not in the **Library**
- **Add to Playlist** may create the **Content** from a **Metadata Provider** when it doesn't exist in WatchClub yet
- **Remove from Playlist** does not delete the **Content**
- Deleting a **User** deletes the **Playlists** they own, also for the **Users** they were shared with
- **Share Playlist** makes the **Playlist** **Shared Unseen** for each **User** it gives **Playlist Access** to, until they open their Playlists. Changing a **User**'s **Playlist Access** doesn't make it **Shared Unseen** again

### Conversations

- A **User** can **Recommend Content** to any other **Users**
- **Recommend Content** starts a new **Conversation** whose **Participants** are the recommending **User** and every **User** they recommended it to
- A **Conversation**'s **Participants** are set when it starts: nobody can join or leave it later
- A **Conversation** is about exactly one **Content**: a **Movie**, a **TV Show**, or a **Book**, never a **TV Show Episode**
- Recommending a **Content** again, even to the same **Users**, starts another **Conversation**
- A **Conversation** always starts with the recommendation itself as its first **Message**, which can include text
- Each **Participant** has read a **Conversation** up to one **Message**; the **Messages** after it are unread for them
- Every **Participant** sees how far the other **Participants** have read
- Any **Participant** can post **Messages** in the **Conversation**
- Only **Participants** can see a **Conversation**
- A **Conversation** shows in the **Inbox** of each of its **Participants**
- Deleting a **User** keeps their **Messages** and their place among the **Participants**, shown as a deleted **User**; their **Conversations** go on for the others

### Requests

- **Add to Playlist** and **Request Content** are independent actions: neither one triggers the other
- A **Content Request** is made by exactly one **User** and references exactly one **Content**
- A **Content** has at most one **Content Request**, made by the first **User** who requests it
- **Request Content** is possible only while the **Content** has no **Content Request** and is missing **Media** for an aired part: the **Movie**, or an aired **TV Show Episode**
- Request does **Request Content** while the **Content** has no **Content Request**, and **Get Notified** once it has one
- Outside **My Requests**, **Content** in the **Library** shows Play, disabled until it is **Ready to Play**; **Content** not in the **Library** shows Request to a **User** who is not a **Request Subscriber**, or its **Content Request Status** to one who is
- In **My Requests**, a **Content Request** that is not Completed shows Play only once its **Content** is **Ready to Play**
- Outside **My Requests**, a **User** who is not a **Request Subscriber** sees **Content** not in the **Library** the same way whether or not somebody else already made its **Content Request**
- Any **User** who isn't a **Request Subscriber** can **Get Notified** on a **Content Request** while its **Content** is not in the **Library**
- The **User** who made a **Content Request** becomes one of its **Request Subscribers**
- Any **Request Subscriber**, the **User** who made the **Content Request** included, can **Stop Getting Notified**
- Only **Request Subscribers** are told when a **Content Request** is Completed: having made it doesn't count
- When a **Content Request** is Completed, it is **Ready Unseen** for each of its **Request Subscribers** until they open **My Requests**. A **Content Request** is Completed once: new **TV Show Episodes** airing later don't make it **Ready Unseen** again
- Other **Users** see who made a **Content Request**, but not its other **Request Subscribers**
- Nobody can cancel a **Content Request**; only the **Instance Administrator** can **Delete Content Request**
- What a **User** sees in **My Requests** is computed when read from the **Media Source Requests** for the **Content**, the **Content**'s **Media**, and whether the **Content Request** is Completed
- Whether a **Content Request** is Completed is separate from whether its **Content** is in the **Library** or **Ready to Play**: a **TV Show** can be both while its **Content Request** is still Downloading. **My Requests** keeps it on the way until it is Completed
- A **Completed Content Request** stays Completed when its **TV Show** becomes an **Incomplete TV Show** again because a new **TV Show Episode** aired
- A **Content Request** has zero or more associated **Media Source Requests**, found via the **Content** it references and the matching **Media Sources**
- A **Media Source Request** is a singleton per (**Content**, **Media Source**) pair
- A **Media Source Request** can only exist for a **Media Source** whose **Media Source Type** supports requests
- A **Media Source Request** comes into existence only _after_ a successful call to its **Media Source** (the movie or series was added or adopted). It is not created speculatively; until the call succeeds there is no **Media Source Request** for that **Media Source**, so its first observable state is Submitted (or Not Released)
- **Request Content** fans out to _every_ request-capable **Media Source** that can serve the **Content** (its **Media Type** produces the **Content**'s **Content Type**), creating one **Media Source Request** per such **Media Source**. This includes multiple **Media Sources** of the same **Media Source Type** (two `radarr` sources each get their own **Media Source Request**) and multiple **Media Types** for one **Content** (a **Book** fans out to both its **Ebook** and **Audiobook** **Media Sources**)
- For a **TV Show**, the singleton is per (**TV Show**, **Media Source**): one **Media Source Request** covers the whole show, never one per **TV Show Episode**. It maps to the single series resource the **Media Source** creates. Per-**TV Show Episode** availability is read from **Media**, not from **Media Source Requests**
- A **Content Request** has a derived progress, the share of the **Content**'s expected parts that have **Media**: for a **Movie** this is all-or-nothing, for a **TV Show** it is available **TV Show Episodes** over _aired_ **TV Show Episodes** (those whose air date has passed). It is computed at read time, not stored
- A **TV Show Episode** records its air date, sourced from the **Metadata Provider**
- The call to a **Media Source** is performed asynchronously when the **Content Request** is created (one call per matching **Media Source**); the **Media Source Request** is recorded once that call succeeds. While the call is in flight the **Content Request** has no **Media Source Request** yet and reads as queued; if the call never succeeds it reads as not found
- A **Content Request** can be created for a **Content** whose **Content Type** has no request-capable **Media Sources**; it simply has no **Media Source Requests**. **Media Source Requests** are created _only_ when the **Content Request** is created, against the **Media Sources** that exist at that moment — there is no backfill. Connecting a request-capable **Media Source** later does nothing for existing **Content Requests**; to have a pre-existing **Content Request** picked up, the **Instance Administrator** uses **Delete Content Request** so the **Content** can be requested again
- When all of a **Content**'s aired parts have **Media** (the **Movie**, or every aired **TV Show Episode**), the **Content Request** is Completed regardless of its **Media Source Requests** — including a **Content Request** with no **Media Source Requests** at all that was later fulfilled by a **Media Import**. **Media** is the authority for fulfillment, not the request machinery
- A **Media Source Request** carries one **Media Source Request State**, recomputed from the **Media Source**'s current state (its movie/series record plus download queue) whenever a webhook or poll arrives; the event triggers a refresh, it does not itself set the state
- A **Media Source Request** stores the **Media Source**'s internal identifier for the resource it created _or adopted_ — a request may adopt a movie or series already present in the **Media Source** rather than failing (e.g. the Radarr movie id, the Sonarr series id)
- A **Media Source Request** persists after **Delete Content Request** (the upstream resource still exists)
- When a **Media Source**'s upstream system reports its movie or series deleted, WatchClub deletes the **Media Source Request** rather than keeping a terminal state; the **Content Request** survives and, with no progressing **Media Source Request**, reads as not found until the **Instance Administrator** fixes it in the **Media Source**'s upstream system or uses **Delete Content Request**
- **Delete Content Request** does not delete any **Media**, any **Media Source Request**, or any resource in any **Media Source**, nor remove the **Content** from any **Playlist**
- A **Media Source Request** in the Needs Attention state is recovered passively: the **Instance Administrator** resolves the problem on the **Media Source**'s upstream system, and the resulting webhook advances the **Media Source Request**. WatchClub has no manual retry action
- A **Content Request** persists independently of any **Playlist** that holds its **Content**
- Every **User** sees every **Content Request**, who made it, and its **Content Request Status**
- **Request Content** may create the **Content** entity from a **Metadata Provider** when no matching **Content** exists in WatchClub yet, before creating the **Content Request**, the same way **Add to Playlist** may create missing **Content**
- A **Content** can exist in WatchClub with no **Media**, referenced only by **Content Requests** or **Playlists**
- **Request Content** currently creates a **Content Request** only for **Movies** and **TV Shows**; **Book** requests are not yet supported (no request-capable **Book** **Media Source** exists — that is the planned `chaptarr` — and the action rejects **Book** content). The **Book**-to-**Ebook**+**Audiobook** fan-out describes the intended design for when `chaptarr` lands, not current behaviour
- Deleting a **User** keeps their **Content Requests**, shown as from a deleted **User**
- Adding or removing a request-capable **Media Source** does not create or remove **Content Requests**, and does not backfill **Media Source Requests** for existing **Content Requests**

### Playback

- A **User** can **Play** or **Download** the **Media** of any **Content** in the **Library**
- **Play** on a **TV Show** starts the **TV Show Episode** the **User** is up to; any other **TV Show Episode** with **Media** plays from the **TV Show**'s episodes
- **Play** opens the **Player** after exactly one **Media** file has been selected
- **Play** starts a new **Playback** in the **User**'s active **Playback Session**, or creates the **Playback Session** when there is none, before playback succeeds
- Advancing to another **Media**, such as the next **TV Show Episode**, creates a new **Playback** in the same **Playback Session**
- Initially, **Playbacks** are created only for **Video** **Media**
- A **Playback Session** is started by exactly one **User**
- A **User** has at most one active **Playback Session**
- A **Playback Session** has zero or more **Playbacks** over its lifetime
- A **Playback** belongs to exactly one **Playback Session** and references exactly one **Media**
- Only the **User** who started a **Playback Session** controls it; the **Instance Administrator** can also see it and its **Playbacks**
- Any **User** can start a **Playback** for any **Media** that has **Content**; WatchClub has no other access rule on playback
- The **Instance Administrator** can additionally start a **Playback** for **Unmatched Media** through the **Media Browser**
- A **Playback Session** has at most one current **Playback** at any time
- A **Playback** is current while it has not ended; it ends when another **Playback** starts in the same **Playback Session**, or when the **Playback Session** ends
- When a **Playback** finishes, its **Playback Session** plays the next available **TV Show Episode** on the same **Screen**; with nothing next, the **Playback Session** ends
- A **Playback Session** is active until it ends: on **Stop Casting**, when nothing is left to play, or after about two minutes without a **Screen**
- A **User** is **Watching Now** while their active **Playback Session** has a **Screen**, paused included
- Every **User** sees which other **Users** are **Watching Now** and what they play, but not their **Playback Sessions**
- Playing **Unmatched Media** doesn't make the **Instance Administrator** **Watching Now**
- A **Playback Session** can exist even when its **Playbacks** later fail
- A **Playback Session** and a **Playback** each record when they were created and when they ended
- A **Playback Session** plays on one **Screen** at a time
- **Play** in a **Player** makes it the **Screen** of the **User**'s **Playback Session**, unless that **Playback Session** plays on a **TV**
- A **Player** that is no longer the **Screen** stops, and tells the **User** that the **Playback Session** plays somewhere else
- The **Screen** in the **User**'s hands acts at once on play, pause and seek; the **Playback Session** then passes the change on
- Only the **Screen** reports the position of its **Playback Session**, which keeps the **User**'s **Watch Progress** up to date
- The **Screen** reports its position about every five seconds, paused or not, and whenever the **User** plays, pauses or seeks
- HLS playlist and segment requests are not position reports
- A **User** can inspect their own **Playback Sessions** and **Playbacks**
- The **Instance Administrator** can inspect **Playback Sessions** by **User** and creation time, and inspect **Playbacks** by **Media** and creation time
- If exactly one **Video** is available for **Play**, playback can start without a selection step
- When multiple **Videos** are available for **Play**, the **User** chooses one before the **Player** opens, using visible **Video Track**, **Audio Track**, and **Text Track** details
- For a **TV Show**, **Play** is offered on individual **TV Show Episodes**, not as a single show-level choice
- When multiple **Media** files are available for **Play** or **Download**, the **User** chooses one
- A **Playback** of new **Content** starts with its **Preferred Audio Track** and **Preferred Text Track**
- The **Preferred Audio Track** is in the **Preferred Audio Language**, otherwise in the original language of the **Content**, otherwise the **Video**'s default **Audio Track**
- The **Preferred Text Track** is a full **Text Track** in the **Preferred Subtitle Language**, unless the audio is in one of the **Languages Without Subtitles**; otherwise, or when the **Video** has none, it is a **Forced Text Track** in the audio's language, if any
- An **Audio Track** without a language is taken to be in the original language of the **Content**
- In the **Player** or the **Remote**, the **User** can switch to any **Audio Track** or **Text Track**, or turn subtitles off
- A **Playback Session** keeps the audio language and the subtitles, or no subtitles, of its **Content**: each next **Playback** of the same **Content**, on any **Screen**, starts with them, whether the **User** picked them or not; when its **Video** has no track in that language, its **Preferred Audio Track** or **Preferred Text Track** applies
- During an **Intro** or a **Recap**, the **Player** offers to skip to its end
- When the **Credits** of a **TV Show Episode** start, or five seconds before its end when it has none, the **Player** counts down five seconds, then plays the next **TV Show Episode** if it has **Media**
- **Watch Progress** counts a **Video** up to the start of its **Credits**
- A **User** can **Report a Problem** about the **Playback** they're in, even when its **Video** fails to play
- A **Problem Report** belongs to the **Playback** it was sent from, which gives its **User**, **Video** and **Content**
- Only the **Instance Administrator** can read and **Archive a Problem Report**; an archived **Problem Report** stays archived
- Deleting a **Video** or a **User** deletes their **Problem Reports**

### Casting

- A **User** can **Cast** only from the **Player**, and only in Chrome on a computer or an Android phone
- **Cast** makes the **TV** the **Screen** of the **Playback Session**, with the same current **Playback**; the **Player** then shows the **Remote**
- While the **Playback Session** plays on a **TV**, **Play** starts its new **Playback** on that **TV**
- Any device of the **User** can open the **Remote**, including devices that can't **Cast**
- The **Remote** never reports a position: the **TV** does
- Leaving the **Remote** leaves the **TV** playing
- Every page shows the **Playback Session** playing on a **TV**, with a way to the **Remote**, only while that **TV** is connected
- Another **User** casting to the same **TV** takes it: the first **Playback Session** loses its **Screen**

### Media

- **Media** is instance-wide
- **Media** has exactly one normalized local filesystem path, and that path is globally unique
- **Media** has exactly one **Media Type**
- **Media** has exactly one concrete **Video**, **Ebook**, or **Audiobook**
- Technical details belong to **Videos**, **Ebooks**, or **Audiobooks**, not to generic **Media**
- Deleting **Media** deletes its concrete **Video**, **Ebook**, or **Audiobook** and their technical details
- Deleting **Media** does not delete **Playback Sessions** or **Playbacks**
- Deleting **Media** does not delete **Content**, **Movies**, **Books**, or **TV Show Episodes**
- A **Video** is attached to at most one **Movie** or at most one **TV Show Episode**
- A **Video** with no attached **Movie** or **TV Show Episode** is **Unmatched Media**
- A **Video** has one or more **Video Tracks**
- A **Video** has exactly one **Default Video Track**
- A **Video** may have zero or more **Audio Tracks**
- A **Video** may have zero or more **Text Tracks**
- A **Video Track** belongs to exactly one **Video**
- An **Audio Track** belongs to exactly one **Video**
- A **Text Track** belongs to exactly one **Video**
- A **Text Track** may be embedded in the **Video** file or provided by a separate local file
- A **Text Track** may identify its language, default selection, and forced selection
- A sidecar **Text Track** file is part of its **Video**, not separate **Media**
- An **Ebook** is attached to exactly one **Book**
- An **Audiobook** is attached to exactly one **Book**
- **Unmatched Media** is not part of the **Library**: it is visible only to the **Instance Administrator**, who can also start a **Playback** for an **Unmatched Media** video
- A **Movie**, **Book**, or **TV Show Episode** can have multiple selectable **Videos**, **Ebooks**, or **Audiobooks**

### Markers

- A **Video** has at most one **Marker** of each kind: **Intro**, **Recap** and **Credits**
- A **Video**'s **Markers** come from its named chapters; a **TV Show Episode**'s missing **Intro** or **Credits** also comes from audio it shares with the nearest **TV Show Episodes** of its **TV Show**
- WatchClub finds a **Video**'s **Markers** in the background each time the **Video** is imported

### Media Sources & Media Imports

- Only the **Instance Administrator** can manage **Media Sources**
- A **Media Source** is used only to import **Media** and, when its **Media Source Type** supports it, to accept **Media Source Requests**; it is not used to play or download **Media** to users
- A **Media Source**'s name is calculated from its configuration
- A **Media Source**'s **Media Type** and **Media Source Type** cannot be edited after creation
- A filesystem **Media Source**'s filesystem location can be edited after it has past **Media Imports**
- A **Media Source** has exactly one **Media Type** and one **Media Source Type**
- A **Media Source** filters out files that do not match its **Media Type**
- A **Media Source** uses its **Media Type** to choose which **Metadata Provider** identifies discovered files
- A **Media Source** can be imported manually by the **Instance Administrator** at any time, including immediately after it is first connected
- A **Media Source** can be imported on a schedule, regardless of **Media Source Type**
- A **Media Source** has attributes specific to its **Media Source Type**
- A **Media Source Type** is one of `filesystem`, `radarr`, or `sonarr` (with `chaptarr` planned); `radarr` and `sonarr` support **Media Source Requests** (as will `chaptarr`), `filesystem` does not
- A request-capable **Media Source** also stores connection details (base URL, API key, webhook secret), the **Media Source**-side settings used when submitting **Media Source Requests** (quality profile, root folder, tags), and the local filesystem path where that root folder appears on WatchClub's disk
- Two request-capable **Media Sources** may point at the same external system (same base URL and same API key) when covering different root folders or different sets of **Media Source**-side settings
- A filesystem **Media Source** has exactly one filesystem location
- A request-capable **Media Source** covers exactly one **Media Source**-side root folder; covering multiple root folders requires multiple **Media Sources**
- Deleting a **Media Source** deletes its **Media Source Requests**, but does not delete **Media**, past **Media Imports**, **Content Requests**, or any resource in the external system
- Filesystem locations may overlap across **Media Sources**
- Multiple **Media Sources** can have the same filesystem location and **Media Type**
- **Book** content can be imported through separate **Media Sources** for **Ebook** and **Audiobook** media types
- A single external system can be represented by multiple **Media Sources** when it provides multiple **Media Types** or covers multiple root folders
- A **Media Import** is started from one **Media Source**
- A **Media Import** starts in the Processing status
- A **Media Import** records whether it was triggered manually or by a schedule, but not which **Instance Administrator** triggered it
- A past **Media Import** remains after its **Media Source** is deleted
- A **Media Import** keeps a snapshot of the **Media Source** that ran
- A **Media Import** has **Refresh Metadata** off by default
- A **Media Import** has one **Media Import Status**: Processing, Completed, Failed, or Cancelled
- A **Media Source** can have at most one Processing **Media Import** at a time
- A **Media Import** is best-effort per file
- A **Media Import** is a two-phase operation: a scan phase that discovers candidate files, then an ingest phase that runs once per candidate to create or refresh **Media**
- The ingest phase can also be triggered directly by a webhook from a `radarr` or `sonarr` **Media Source** for a single file, without re-running the scan phase and without recording a **Media Import**
- Webhook-triggered ingest always behaves as if **Refresh Metadata** were on
- Scan phases differ by **Media Source Type**: a filesystem scan walks the configured location; an `radarr` or `sonarr` scan calls the **Media Source**'s API to enumerate its catalog
- A **Failed** **Media Import** is one that cannot finish processing its source
- A **Cancelled** **Media Import** is one that the **Instance Administrator** ended before it finished, or that was left **Processing** by a previous run of WatchClub
- **Cancel Media Import** ends the scan phase; in-flight per-file ingest jobs continue to completion
- Files filtered out by **Media Type**, hidden files, and hidden folders are ignored by filesystem imports
- Filesystem imports do not follow symbolic links
- A filesystem import recursively examines its **Media Source**'s filesystem location
- A **Media Import** creates **Media** only for files with a local filesystem path accessible to WatchClub
- A **Media Import** inspects local files before creating **Videos**, **Ebooks**, or **Audiobooks**
- **Playback Sessions** use the stored technical details of **Media**
- **Play** does not refresh technical details before opening the **Player**
- A filesystem import discovers sidecar **Text Tracks** for **Videos**, without creating separate **Media** for those sidecar files
- A **Media Import** may create missing **Content** when a **Metadata Provider** confidently identifies it
- Content created by a **Media Import** includes all available **Content Localizations**
- A **Media Import** may create a missing **Movie** or **Book** before creating **Media** for it
- When a **Media Import** identifies a video file as an episode of an unknown **TV Show**, it creates the **TV Show** and all known regular **TV Show Episodes** together before creating the **Video**
- A **Media Import** refreshes the **Content** of each file it matches when its metadata is older than 15 minutes
- A file whose **TV Show Episode** is still missing after that fails ingestion; a later scan retries it because no **Media** was saved
- **Media Imports** exclude specials when creating **TV Show Episodes**
- A **Media Import** does not create a single **TV Show Episode** on its own
- When **Refresh Metadata** is off, an existing **Media** found again by a **Media Import** is skipped
- When **Refresh Metadata** is on, a **Media Import** rematches existing **Media** and recreates its concrete media details
- When **Refresh Metadata** is off, a **Media Import** skips existing **Media** even when the same path would now match different **Content** or **Media Type**
- A filesystem **Media Import** deletes **Media** whose path is no longer present under the configuration’s filesystem location
- Moving a file deletes the old **Media** and creates new **Media** at the new path
- Overlapping filesystem imports can run at the same time

### Contents

- A **Movie**, **TV Show**, and **Book** are kinds of **Content**
- A **Content** is identified by its **Content Type**, **Metadata Provider** and **External ID**; different **Content Types** may share the same **External ID**
- The same real-world work from two **Metadata Providers** may be represented as separate **Content** until explicitly reconciled
- A **Content** has exactly one **Content Type**
- A **Content** can have multiple **Content Localizations**
- A **Content** has at most one **Content Localization** per **Locale**
- A **Movie** or **TV Show** has zero or more **Genres**, from its **Metadata Provider**
- **Movies** and **TV Shows** share the same **Genres**: a TMDB TV genre that combines two, such as Action & Adventure, gives both
- A **Movie** or **TV Show** has a **Rating** only once at least 25 people voted on its **Metadata Provider**, so a single vote can't top Best rated
- A **TV Show** has zero or more **TV Show Episodes**
- A **TV Show Episode** belongs to exactly one **TV Show**
- A **TV Show Episode** has at most one **TV Show Episode Localization** per **Locale**
- Opening a **Content** page creates missing **Content** in the background, showing a loading state until it exists
- **Content** pages show stored metadata immediately and refresh it in the background when older than a day
- **Content** pages include retained **TV Show Episodes** no longer listed by the **Metadata Provider**
- Refreshing metadata updates existing **Content**, **Content Localizations** and **TV Show Episodes** in place, preserving **Watch Progress** and **Media** links
- If the **Metadata Provider** is unavailable, existing **Content** remains usable with its last stored metadata
- A **TV Show** cannot have two **TV Show Episodes** with the same season number and episode number
- A **TV Show Episode** has a season number greater than or equal to 1
- A **TV Show Episode** has an episode number greater than or equal to 1
- A **TV Show Episode** has aired once its air date has passed
- A **User** has finished a **TV Show** once they have finished every aired **TV Show Episode**. Marking a season or a whole **TV Show** as watched marks its aired **TV Show Episodes** only
- Every **User** sees the **Watchers** of every **Content**, whether each finished it, and when they last watched it
- A **User** has one **Preferred Content Localization** for each **Content** when a matching localization exists
- A **Content** is in the **Library** while it has **Media**; a **TV Show** is in it while any of its **TV Show Episodes** has **Media**
- A **User** gets missing **Content** into the **Library** with **Request Content**
- Every **User** sees the whole **Library** in **Browse**
- Every **User** sees which **TV Shows** are **Incomplete TV Shows**, whether or not they have a **Content Request**. A **TV Show** is incomplete, for example, while its **Content Request** brings its **TV Show Episodes**, after a new one airs until it has **Media**, or when it was imported with gaps

### Home

- **Home** shows the **User**'s **Content** in progress, their **For You**, the **Content** most recently added to the **Library**, who is **Watching Now**, and the **Activity Feed**
- **For You** shows its 5 latest items, newest first, whether or not the **User** has seen them
- A **Content** is new in the **Library** from when its first **Media** arrives: new **TV Show Episodes** of a **TV Show** already in the **Library** don't make it new again
- **Home** shows a **Content** with a **Content Request** among the newest in the **Library** only once that **Content Request** is Completed

### Activity Feed

- A **Feed Entry** holds the **Feed Events** of one **User** doing the same thing
- A **Feed Event** joins the latest **Feed Entry** of the same **User** doing the same thing when that entry's first **Feed Event** is less than 12 hours old; otherwise it starts a new **Feed Entry**
- A **Feed Entry** is placed at the time of its latest **Feed Event**
- When a **User**'s **Watch Progress** on a **Content** changes, their watching **Feed Event** for it moves to that time, and to a new **Feed Entry** if the old one's 12 hours are over. While they play, this happens at most once a minute
- Every **User** sees the **Feed Events** of every **User**, their own included
- A **User** cannot hide what they watch from the **Activity Feed**

## Example dialogue

> **Dev:** "Does adding a movie to a **Playlist** recommend it to anyone?"
> **Domain expert:** "No. A **Playlist** stays private until its owner shares it. To send a movie to people, you **Recommend Content**, which starts a **Conversation** with them."
> **Dev:** "Where do the files we play come from?"
> **Domain expert:** "An **Instance Administrator** defines a **Media Source**, and each **Media Import** discovers instance-wide **Media**. Its **Content** joins the **Library**, which every **User** sees in **Browse**."

## Flagged ambiguities

- "Admin" is ambiguous; resolved: use **Instance Administrator** for the user who administers the instance.
- "Invitee" can imply a known person, but an **Invitation** only stores an **Invitee Name** until someone accepts it.
- "Share" means giving access to a **Playlist**; resolved: sending **Content** to people is **Recommend Content**.
- A separate **Get Notified** action next to somebody else's **Content Request** was considered; resolved: outside **My Requests**, a **User** who is not a **Request Subscriber** only sees Request, because whether somebody else already requested the **Content** doesn't change what they can do.
- **Download** is a **User** saving a file to their device; resolved: the Downloading **Content Request Status** is a **Media Source** fetching the file to the server.
- **Browse** and the **Media Browser** are different interfaces: **Browse** shows **Content** to every **User**, the **Media Browser** shows **Media** files to the **Instance Administrator**.
- "Media Version" is not canonical; resolved: use **Media** for the local file and **Video**, **Ebook**, or **Audiobook** for concrete media.
- **Media Type** and **Content Type** are distinct but coupled; resolved: **Media Type** classifies **Media** with four values (Movie, TV Show Episode, Ebook, Audiobook) and implies the expected **Content Type** for the attached **Content**.
- "Scan Library" and "sync" are not canonical; resolved: use **Media Source** for the configuration and **Media Import** for the one-way operation.
- "Media Server Library" is not canonical; resolved: use **Media Source** for where **Media** comes from, and **Library** for all the **Content** that has **Media**.
- "External Source" was replaced by **Metadata Provider** for catalogs such as TMDB or Hardcover.
- "Automation Service" and "Request Profile" are not canonical; resolved: the upstream system, the connection details, and the request-side settings are all attributes of a **Media Source**. An `radarr` or `sonarr` **Media Source** is both an import source and a request destination; a `filesystem` **Media Source** is import-only.
- **Pending Content Request**, **Requested Content Request**, **Available Content Request**, and **Failed Content Request** are not canonical: the displayed **Content Request Status** _is_ canonical, but as a _derived read-model value_ computed when read from the **Content**'s **Media** and its **Media Source Requests** — vocabulary, not a stored attribute. Only **Completed Content Request** is a canonical subtype, because a **Content Request** stays Completed once it is.
- "Playable" meant **Content** with any **Media**, so a **TV Show** looked ready, and Play could start whichever **TV Show Episode** downloaded first; resolved: **Library** for **Content** with any **Media**, **Ready to Play** for what **Play** can start for a **User**, and **Completed Content Request** for a **Content Request** whose every aired part has **Media**.
- The work a request-capable **Media Source** does for one piece of **Content** is a first-class concept tracked as a **Media Source Request**. A **Media Source Request** is not user-scoped. "Request Attempt" was an earlier working name; the canonical term is **Media Source Request**.
- "Request Media" is not a canonical action; resolved: **Request Content** is the user action that creates a **Content Request**. It is independent of **Playlists**: **Add to Playlist** does not create a **Content Request**.
- "User settings" may appear where the domain means **User Preferences**; resolved: the canonical term is **User Preferences**.
- "Episode" is ambiguous across content types; resolved: use **TV Show Episode** for numbered parts of **TV Show** content.
- External provider episode IDs are not the canonical identity for **TV Show Episodes**; resolved: a **TV Show Episode** is identified within a **TV Show** by season number and episode number.
- Specials are not modeled as **TV Show Episodes**; resolved: a **TV Show Episode** season number starts at 1.
- Radarr and Sonarr are **Media Source Types** that both accept **Media Source Requests** (WatchClub asks them to make content available) and serve as import sources (WatchClub imports the resulting **Media**). One **Media Source** of these types covers both directions of the integration. `chaptarr` is a planned third request-capable type (for **Book** content) and is not yet implemented; the glossary keeps it to document the intended direction, not a live type. Because no request-capable **Book** source exists, **Request Content** today serves only **Movies** and **TV Shows**; the **Book** fan-out is intended design, not current behaviour.
- "Segment" means an HLS segment; resolved: the parts of a **Video** that the **Player** lets a **User** skip are **Markers**. Chapters are only where some **Markers** come from: WatchClub doesn't store them.
- "Outro" is not canonical; resolved: use **Credits**.
- "Play Media" and "Play Video" are not canonical user actions; resolved: use **Play** for the user action and reserve **Media** and **Video** for what is selected to play.
- "Video data" is not canonical; resolved: when choosing among **Videos**, describe the visible **Video Track**, **Audio Track**, and **Text Track** details.
- "Player Session" and "HLS Session" are technical names for parts of playback, but the domain concept is **Playback Session**.
- **Playback Session** is distinct from **Watch Progress**; resolved: a Playback Session is what a **User** is watching right now, while Watch Progress records how far a **User** has got through a **Movie** or **TV Show Episode** overall and whether they finished it.
- **Playback Session** is scoped to the **User**, not to one **Player** visit or one device: it moves between **Screens**; the selected **Media** lives on each **Playback** inside it.
- A separate "Cast Session" was considered; resolved: casting moves the **Playback Session** to a **TV**, and the **TV** is only its **Screen**.
- "Stream" and "HLS Stream" are technical names for the runtime state of one media file being played; the domain concept is **Playback** (one **Media** being played inside a **Playback Session**).
- "Playback probe" and "start-of-session probe" are not canonical; resolved: playback uses stored technical details, refreshed only by re-running a **Media Import** with **Refresh Metadata** on.
- "Media Import Result" is not canonical; resolved: per-file outcomes are not persisted today, only the **Media Import**'s overall **Media Import Status**.
- The second phase of a **Media Import** is the **ingest phase** (formerly called the "processing phase"); resolved: the two phases are the **scan phase** and the **ingest phase**. This is distinct from the **Media Import Status** value Processing, which is a separate axis (the whole import being in progress) and keeps its name.
- "Is watching" in the **Activity Feed** means the **User** has unfinished **Watch Progress**, possibly from days ago; resolved: **Watching Now** means their **Playback Session** plays on a **Screen** right now.
- Grouping **Feed Events** by day was considered; resolved: a **Feed Entry** spans at most 12 hours from its first **Feed Event**, like Mastodon's grouped notifications, so grouping needs no day boundary or time zone.
