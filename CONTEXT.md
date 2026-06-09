# WatchClub

WatchClub is a space for small private groups to collect, share, and discuss content.

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

**Instance Administrator**:
The single user who administers the WatchClub instance and can create clubs.
_Avoid_: Administrator, admin, owner

### Clubs

**Club**:
A private group of people who share content and coordinate watching or reading together.
_Avoid_: Community, group, workspace

**Member**:
A user who belongs to a specific club.
_Avoid_: Participant, club user

**Membership**:
A user’s belonging to a club as either a **Club Admin** or **Club Member**.
_Avoid_: Subscription, enrolment

**Club Admin**:
A member who can manage the club, its libraries, members, invitations, and library items.
_Avoid_: Admin, owner

**Club Member**:
A member who can view libraries, add content to them, and remove library items they added.
_Avoid_: Regular user, participant

**Invitation**:
An instance-wide link created by the **Instance Administrator** that lets new people register and, on doing so, join zero or more **Clubs** as **Club Members**. Redeemable only while it is not **Expired**, not **Disabled**, and not **Exhausted**.
_Avoid_: Invite, invitation code, club invitation

**Use Limit**:
The optional maximum number of new accounts an **Invitation** can create. Unlimited when unset.
_Avoid_: Max uses, seats, quota

**Redeem Invitation**:
A new person registers through an **Invitation**, creating their **User** and one **Club Member** **Membership** in each granted **Club**. Counts as one use against the **Use Limit**.
_Avoid_: Accept invitation, join instance

**Expired Invitation**:
An invitation that can no longer be redeemed because its redemption window has passed.
_Avoid_: Invalid invitation, stale invitation

**Exhausted Invitation**:
An invitation that has reached its **Use Limit** and can no longer be redeemed.
_Avoid_: Used invitation, used-up invitation, spent invitation

**Disable Invitation**:
Deactivate a still-redeemable **Invitation** so its link can no longer be redeemed, without removing the **Users** and **Memberships** it already created. Cannot be applied to an **Exhausted Invitation**.
_Avoid_: Delete invitation, revoke invitation, cancel invitation, archive invitation

**Library**:
A named collection of content inside a club for exactly one content type.
_Avoid_: Club Library, list, shelf, playlist

**Library Item**:
A piece of content included in a library.
_Avoid_: Recommendation, availability, selection

**Add to Library**:
Include content in a library so it is visible to club members.
_Avoid_: add to club, recommend, make available

**Remove from Library**:
Remove a library item from a library without deleting the underlying content.
_Avoid_: Remove from club library, delete content, remove content

**Delete Library**:
Permanently remove a library and its library items without deleting the underlying content.
_Avoid_: Delete club library, remove library

**Play Library Item**:
Play available **Media** for a library item through WatchClub.
_Avoid_: Stream content, watch media, play media server item

**Download Library Item**:
Download a video, ebook, or audiobook for a library item through WatchClub.
_Avoid_: Download content, download media, download media server item

**Content Request**:
A user’s request for WatchClub to make a piece of content available on the media server for that user’s personal consumption.
_Avoid_: Media Request, Request Media, download request, fetch request, acquisition request

**Content Request Status**:
The status of a **Content Request** as shown on **My Requests**, derived at read time (never stored) from the **Content**'s **Media** and its **Media Source Requests**. One of: Not Released, Not Found, Queued, Downloading, Importing, Completed, Failed. *Importing* means a **Media Source** reports the file downloaded but its **Media** has not yet been ingested into WatchClub, so a request never shows Completed until **Media** exists. *Queued* is the label for a just-submitted request still within its grace window or whose **Media Source** call is still in flight.
_Avoid_: Pending, Requested, Available, request state, Media Source Request State

**Content Request Status Group**:
The coarse grouping of **Content Request Statuses** used by the **My Requests** filter. One of: In Progress (Queued, Downloading, Importing), Completed, Failed, Not Released, Not Found.
_Avoid_: Status filter, request category

**Media Source Request**:
WatchClub's record of asking one **Media Source** to make one **Content** available. Singleton per (**Content**, **Media Source**) pair, shared by every **Content Request** for that **Content**. Only **Media Sources** whose **Media Source Type** supports requests can be the **Media Source** of a **Media Source Request**. In practice, referred to by the **Media Source Type**, e.g. "Radarr Request", "Sonarr Request".
_Avoid_: Request Attempt, Profile Request, Sourcing

**Media Source Request State**:
The progress of a **Media Source Request** in its **Media Source**, recorded on the **Media Source Request** itself and *reconciled from the **Media Source**'s current state* (not driven by individual events). One of: Submitted, Not Released, Downloading, Partially Downloaded, Downloaded, Needs Attention.
_Avoid_: Request Attempt State, *arr status, Grabbed, Searching, Cancelled, Created

**Request Content**:
A user creates a **Content Request** for one piece of **Content** so its media file is brought to the media server for them.
_Avoid_: Request media, fetch content, grab content, add to my downloads, add to watchlist

**Cancel Content Request**:
A user removes one of their own **Content Requests**.
_Avoid_: Delete request, abort request, unrequest

**My Requests**:
The WatchClub interface where a user views and manages their own **Content Requests**.
_Avoid_: My downloads, watchlist, request inbox

**Leave Club**:
A member ends their own membership in a club.
_Avoid_: Quit club, unsubscribe

**Remove Member**:
A **Club Admin** ends another member’s membership in a club.
_Avoid_: Delete member, ban

**Delete Club**:
Permanently remove a club and everything that exists only inside it, without deleting content that may be used elsewhere.
_Avoid_: Archive club, close club

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
The WatchClub interface where a member watches a selected video.
_Avoid_: Video player page, stream page

**Playback Session**:
One continuous use of the **Player** by a user. A **Playback Session** does not itself reference a selected media file; that belongs to each **Playback** inside it.
_Avoid_: Player Session, HLS Session, stream session, watch session, watch history

**Playback**:
One **Media** being played by a user inside a **Playback Session**.
_Avoid_: Stream, HLS Stream, play, playthrough

**Watch Progress**:
How far a **User** has got through one **Movie** or one **TV Show Episode**, and whether they have finished it. Tied to the watchable work, not to a specific **Media**, so the several **Videos** that back one **Movie** or **Episode** share a single Watch Progress. Covers video only for now; reading a **Book** or listening to an **Audiobook** would be sibling concepts, not the same record.
_Avoid_: watch history, watch session, resume point, playhead, watched flag

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

### Contents

**Content**:
A creative work that can be added to a library, such as a movie, TV show, or book.
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


## Relationships

### Accounts

- A **User** has exactly one **Username**
- There is at most one **Instance Administrator**
- A **User** has one set of **User Preferences**
- **User Preferences** belong to one **User** and are managed only by that **User**
- **User Preferences** include the user’s preferred **Locale**
- Deleting a **User** does not delete their **Playback Sessions** or **Playbacks**

### Clubs

- A **Club** is visible only to its **Members**, except through an **Invitation**
- A **Club** has one or more **Members**
- A **Club** has exactly one **Club Admin**
- A **Club Admin** and a **Club Member** are both **Members**
- A **Membership** belongs to exactly one **User** and exactly one **Club**
- A **Membership** may originate from an **Invitation**
- The **Club Admin** cannot **Leave Club** or be the target of **Remove Member**
- Only a **Club Admin** can view the full member and invitation list for a **Club**
- A **Club Member** can view only their own **Membership**
- **Leave Club** ends the acting **Club Member**’s **Membership** without removing **Library Items** they added
- **Remove Member** ends another **Member**’s **Membership** without removing **Library Items** they added
- An **Invitation** is instance-wide and grants membership to zero or more **Clubs**
- An **Invitation** granting zero **Clubs** lets a new person register without joining any **Club**; the **Instance Administrator** adds them to **Clubs** later
- An **Invitation** is created and managed only by the **Instance Administrator**
- An **Invitation** is link-based and is not tied to any **User** before redemption
- An **Invitation** is redeemed only by a new person registering; an existing **User** can never redeem one
- **Redeem Invitation** creates the new **User** and one **Club Member** **Membership** per granted **Club**, and counts as one use against the **Use Limit**
- An **Invitation** records its originating **Use Limit**; uses are counted from the **Users** it created, not stored
- An **Expired Invitation**, a **Disabled** **Invitation**, and an **Exhausted Invitation** cannot be redeemed
- **Disable Invitation** can be applied at any time except to an **Exhausted Invitation**, and leaves already-created **Users** and **Memberships** intact
- A **Club** has zero or more **Libraries**
- A **Library** belongs to exactly one **Club**
- A **Library** has exactly one **Content Type**
- A **Club** can have multiple **Libraries** with the same **Content Type**
- Only **Members** can view a **Club**’s **Libraries** and **Library Items**
- A **Library** contains zero or more **Library Items**
- A **Library** contains only **Library Items** whose **Content** has the same **Content Type** as the **Library**
- A **Library** can contain a given **Content** at most once
- The same **Content** can appear in multiple **Libraries**
- A **Library Item** belongs to exactly one **Library** and references exactly one **Content**
- A **Library Item** is visible to all **Members** of its **Club**
- A **Library Item** is added by a **Member**
- **Add to Library** creates a **Library Item**
- Any **Member** can **Add to Library** when the **Content** matches the **Library**’s **Content Type**
- If the adding **Member** later leaves the **Club**, the **Library Item** remains in the **Library**
- If a **User** is deleted, **Library Items** they added remain in their **Libraries** without an adding **Member**
- **Remove from Library** removes a **Library Item** but not its **Content**
- A **Club Admin** can **Remove from Library** for any **Library Item**
- A current **Member** who added a **Library Item** can **Remove from Library** for that item
- A former **Member** cannot **Remove from Library** unless they rejoin the **Club**
- If a **Library Item** has no adding **Member**, only a **Club Admin** can **Remove from Library** for it
- A **Member** can **Play Library Item** or **Download Library Item** for any **Library Item** visible to them in WatchClub
- **Play Library Item** opens the **Player** after exactly one **Media** file has been selected
- **Play Library Item** from outside the **Player** creates a **Playback Session** and its first **Playback** for the selected **Media** when the **Player** opens, before playback succeeds
- While the **Player** is open, advancing to another **Media** (for example the next **TV Show Episode**) creates a new **Playback** on the same **Playback Session**
- Initially, **Playbacks** are created only for **Video** **Media**
- A **Playback Session** is started by exactly one **User**
- A **Playback Session** has zero or more **Playbacks** over its lifetime
- A **Playback** belongs to exactly one **Playback Session** and references exactly one **Media**
- Only the starting **User** and the **Instance Administrator** can access a **Playback Session** or any of its **Playbacks**
- Any **User** can start a **Playback** for any **Media**; WatchClub does not gate playback on **Library Item** visibility or any other access rule
- What a **User** *sees* in WatchClub is constrained by their **Memberships** and their **Content Requests**; what they can *play* once reached is not
- The **Instance Administrator** can additionally start a **Playback** for **Unmatched Media** through the **Media Browser**
- A **Playback Session** is not scoped to a **Club**, **Library**, or **Library Item**
- A **Playback** is current while it has not ended; it ends when the **Player** closes or when another **Playback** starts on the same **Playback Session**
- A **Playback Session** has at most one current **Playback** at any time
- A **Playback Session** is active while it has a current **Playback**; it is dormant otherwise
- A **User** may have multiple active **Playback Sessions** at once (for example, two open **Player** tabs); each is its own visit
- A later **Play Library Item** from outside the **Player** for the same **Media** creates a separate **Playback Session** with its own first **Playback**
- A **Playback Session** can exist even when its **Playbacks** later fail
- A **Playback Session** records only when it was created; its activity is derived from its **Playbacks**
- A **Playback** records its selected **Media**, when it was created, when it was last active, and when it ended
- The **Player** is active when it is playing or when the **User** interacts with playback controls
- Only **Player** heartbeats update the current **Playback**'s last active time
- While the **Player** is playing, it sends a heartbeat about every five seconds
- The **Player** also sends a heartbeat when the **User** interacts with playback controls
- HLS playlist and segment requests do not update a **Playback**'s last active time
- A **Playback** has an explicit ended time; a **Playback Session** has no explicit ended state and is considered active or dormant based on whether it has a current **Playback**
- A **User** can inspect their own **Playback Sessions** and **Playbacks**
- The **Instance Administrator** can inspect **Playback Sessions** by **User** and creation time, and inspect **Playbacks** by **Media**, creation time, and last active time
- If the same **Content** is visible to a **User** through multiple **Library Items**, one **Playback** for its **Media** may be relevant to each corresponding club activity feed
- A **Library Item** can exist when its **Movie**, **Book**, or **TV Show Episodes** have no **Media**
- Adding **Content** to a **Library** and playing available **Media** are independent member actions
- If exactly one **Video** is available for **Play Library Item**, playback can start without a selection step
- When multiple **Videos** are available for **Play Library Item**, the **Member** chooses one before the **Player** opens, using visible **Video Track**, **Audio Track**, and **Text Track** details
- For a **TV Show** **Library Item**, **Play Library Item** is offered on individual **TV Show Episodes**, not as a single show-level choice
- When multiple **Media** files are available for **Play Library Item** or **Download Library Item**, the **Member** chooses one
- **Add to Library** treats the **Library Item**’s **Content** as a whole; for **TV Show** content this is the entire **TV Show**, not a season or **TV Show Episode**
- When the **Library** already contains the **Content**, **Add to Library** does not create a duplicate **Library Item**
- **Add to Library** and **Request Content** are independent actions: **Add to Library** creates only a **Library Item**, **Request Content** creates only a **Content Request**, and neither one triggers the other
- A **Content Request** belongs to exactly one **User** and references exactly one **Content**
- A **User** has at most one **Content Request** for a given **Content**
- A **Content Request** has no stored status; what a **User** sees in **My Requests** is computed at read time from the **Media Source Requests** for the **Content** and from the **Content**'s **Media**
- Whether a **Content Request** is *playable* is a read-time flag separate from its displayed status: true once the **Content** has **Media** for the **Movie** or for the **TV Show**'s first **TV Show Episode** (season 1, episode 1). A **Content Request** can be playable while still showing an in-progress status (a **TV Show** whose first episode is present while more are downloading), so playability drives the Play action independently of status
- A **Content Request** has zero or more associated **Media Source Requests**, found via the **Content** it references and the matching **Media Sources**
- A **Media Source Request** is a singleton per (**Content**, **Media Source**) pair, shared by every **Content Request** for that **Content**
- A **Media Source Request** can only exist for a **Media Source** whose **Media Source Type** supports requests
- A **Media Source Request** comes into existence only *after* a successful call to its **Media Source** (the movie or series was added or adopted). It is not created speculatively; until the call succeeds there is no **Media Source Request** for that **Media Source**, so its first observable state is Submitted (or Not Released)
- **Request Content** fans out to *every* request-capable **Media Source** that can serve the **Content** (its **Media Type** produces the **Content**'s **Content Type**), creating one **Media Source Request** per such **Media Source**. This includes multiple **Media Sources** of the same **Media Source Type** (two `radarr` sources each get their own **Media Source Request**) and multiple **Media Types** for one **Content** (a **Book** fans out to both its **Ebook** and **Audiobook** **Media Sources**)
- For a **TV Show**, the singleton is per (**TV Show**, **Media Source**): one **Media Source Request** covers the whole show, never one per **TV Show Episode**. It maps to the single series resource the **Media Source** creates. Per-**TV Show Episode** availability is read from **Media**, not from **Media Source Requests**
- A **Content Request** has a derived progress, the share of the **Content**'s expected parts that have **Media**: for a **Movie** this is all-or-nothing, for a **TV Show** it is available **TV Show Episodes** over *aired* **TV Show Episodes** (those whose air date has passed). It is computed at read time, not stored
- A **TV Show Episode** records its air date, sourced from the **Metadata Provider**
- The call to a **Media Source** is performed asynchronously when the **Content Request** is created (one call per matching **Media Source**); the **Media Source Request** is recorded once that call succeeds. While the call is in flight the **Content Request** has no **Media Source Request** yet and reads as queued; if the call never succeeds it reads as not found
- A **Content Request** can be created for a **Content** whose **Content Type** has no request-capable **Media Sources**; it simply has no **Media Source Requests**. **Media Source Requests** are created *only* when the **Content Request** is created, against the **Media Sources** that exist at that moment — there is no backfill. Connecting a request-capable **Media Source** later does nothing for existing **Content Requests**; to have a pre-existing **Content Request** picked up, the **User** cancels and re-requests
- When all of a **Content**'s aired parts have **Media** (the **Movie**, or every aired **TV Show Episode**), the **Content Request** reads as complete regardless of its **Media Source Requests** — including a **Content Request** with no **Media Source Requests** at all that was later fulfilled by a **Media Import**. **Media** is the authority for fulfillment, not the request machinery
- A **Media Source Request** carries one **Media Source Request State**, recomputed from the **Media Source**'s current state (its movie/series record plus download queue) whenever a webhook or poll arrives; the event triggers a refresh, it does not itself set the state
- A **Media Source Request** stores the **Media Source**'s internal identifier for the resource it created *or adopted* — a request may adopt a movie or series already present in the **Media Source** rather than failing (e.g. the Radarr movie id, the Sonarr series id)
- A **Media Source Request** persists after every claiming **Content Request** is cancelled (it is shared, and the upstream resource still exists)
- When a **Media Source**'s upstream system reports its movie or series deleted, WatchClub deletes the **Media Source Request** rather than keeping a terminal state; the **Content Request** survives and, with no progressing **Media Source Request**, reads as not found until cancelled and re-requested
- **Cancel Content Request** removes the **Content Request** and does not delete any **Media**, any **Library Item**, any **Media Source Request**, or any resource in any **Media Source**
- A **Media Source Request** in the Needs Attention state is recovered passively: the **Instance Administrator** resolves the problem on the **Media Source**'s upstream system, and the resulting webhook advances the **Media Source Request**. WatchClub has no manual retry action
- **Remove from Library** does not affect the adding **Member**’s **Content Request** or any other **User**’s **Content Request**
- A **User**’s **Content Request** persists independently of their **Memberships** and of the lifecycle of any **Library Item**
- A **User**’s **Content Requests** are visible only to that **User** and to the **Instance Administrator**; other **Users**, including co-**Members** of any **Club**, cannot see them
- The **Instance Administrator** can inspect all **Content Requests** in WatchClub
- **Request Content** may create the **Content** entity from a **Metadata Provider** when no matching **Content** exists in WatchClub yet, before creating the **Content Request**, the same way **Add to Library** may create missing **Content**
- A **Content** can exist in WatchClub referenced only by **Content Requests**, with no **Library Items** and no **Media**
- **Request Content** currently creates a **Content Request** only for **Movies** and **TV Shows**; **Book** requests are not yet supported (no request-capable **Book** **Media Source** exists — that is the planned `chaptarr` — and the action rejects **Book** content). The **Book**-to-**Ebook**+**Audiobook** fan-out describes the intended design for when `chaptarr` lands, not current behaviour
- Deleting a **User** deletes their **Content Requests**; any **Media** acquired through those requests remains in WatchClub
- Only a **Club Admin** can **Delete Library**
- **Delete Library** removes the **Library** and its **Library Items**, but not their **Content**
- Only a **Club Admin** can **Delete Club**
- **Delete Club** removes the **Club**’s **Memberships**, **Libraries**, and **Library Items**, but not **Content** or **Media**
- **Delete Club** drops the **Club** from every **Invitation** that grants it; those **Invitations** survive, even if left granting zero **Clubs**
- Adding or removing a request-capable **Media Source** does not create or remove **Content Requests**, and does not backfill **Media Source Requests** for existing **Content Requests**
- **Add to Library** cannot be repeated for **Content** that is already in the **Library**

### Media

- **Media** is instance-wide and belongs to no **Library**
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
- **Unmatched Media** cannot reach a **Library Item** and is visible only to the **Instance Administrator**, who can also start a **Playback** for an **Unmatched Media** video
- A **Movie**, **Book**, or **TV Show Episode** can have multiple selectable **Videos**, **Ebooks**, or **Audiobooks**

### Media Sources & Media Imports

- Only the **Instance Administrator** can manage **Media Sources**
- A **Media Source** is not scoped to a **Library** or **Club**
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
- **Play Library Item** does not refresh technical details before opening the **Player**
- A filesystem import discovers sidecar **Text Tracks** for **Videos**, without creating separate **Media** for those sidecar files
- A **Media Import** may create missing **Content** when a **Metadata Provider** confidently identifies it
- Content created by a **Media Import** includes all available **Content Localizations**
- A **Media Import** may create a missing **Movie** or **Book** before creating **Media** for it
- When a **Media Import** identifies a video file as an episode of an unknown **TV Show**, it creates the **TV Show** and all known regular **TV Show Episodes** together before creating the **Video**
- When a **Media Import** needs a missing **TV Show Episode** for an existing **TV Show**, it refreshes the **TV Show** as a whole
- **Media Imports** exclude specials when creating **TV Show Episodes**
- A **Media Import** does not create a single **TV Show Episode** on its own
- A **Media Import** does not create **Library Items**
- When **Refresh Metadata** is off, an existing **Media** found again by a **Media Import** is skipped
- When **Refresh Metadata** is on, a **Media Import** rematches existing **Media** and recreates its concrete media details
- When **Refresh Metadata** is off, a **Media Import** skips existing **Media** even when the same path would now match different **Content** or **Media Type**
- A filesystem **Media Import** deletes **Media** whose path is no longer present under the configuration’s filesystem location
- Moving a file deletes the old **Media** and creates new **Media** at the new path
- Overlapping filesystem imports can run at the same time

### Contents

- A **Movie**, **TV Show**, and **Book** are kinds of **Content**
- A **Content** is identified in a **Metadata Provider** by an **External ID**
- The same real-world work from two **Metadata Providers** may be represented as separate **Content** until explicitly reconciled
- A **Content** has exactly one **Content Type**
- A **Content** can have multiple **Content Localizations**
- A **Content** has at most one **Content Localization** per **Locale**
- A **TV Show** has zero or more **TV Show Episodes**
- A **TV Show Episode** belongs to exactly one **TV Show**
- A **TV Show** cannot have two **TV Show Episodes** with the same season number and episode number
- A **TV Show Episode** has a season number greater than or equal to 1
- A **TV Show Episode** has an episode number greater than or equal to 1
- A **User** has one **Preferred Content Localization** for each **Content** when a matching localization exists

### Cross-domain

- A **User** can have memberships in many **Clubs**
- A **Club** is created by the **Instance Administrator**, who becomes its **Club Admin**
- The **Club Admin** cannot be replaced
- An **Invitation** is the only way a new person joins **Clubs**; once a **User** exists, the **Instance Administrator** adds them to a **Club** directly rather than through an **Invitation**
- A **User** records the **Invitation** they registered through, if any

## Example dialogue

> **Dev:** "Does adding a movie to a **Library** mean the club recommends it?"
> **Domain expert:** "No — **Add to Library** creates a **Library Item** so the **Content** is visible to the **Club**."
> **Dev:** "Where do playable files come from?"
> **Domain expert:** "An **Instance Administrator** defines a **Media Source**, and each **Media Import** discovers instance-wide **Media** without adding anything to club **Libraries**."

## Flagged ambiguities

- "Admin" was used ambiguously; resolved: use **Instance Administrator** for the instance-level user and **Club Admin** for the privileged club membership assigned at club creation.
- "Invitee" can imply a known person, but an **Invitation** only stores an **Invitee Name** until someone accepts it.
- "Club Library" is not canonical; resolved: the canonical term is **Library**.
- "Media Version" is not canonical; resolved: use **Media** for the local file and **Video**, **Ebook**, or **Audiobook** for concrete media.
- **Media Type** and **Content Type** are distinct but coupled; resolved: **Media Type** classifies **Media** with four values (Movie, TV Show Episode, Ebook, Audiobook) and implies the expected **Content Type** for the attached **Content**.
- "Scan Library" and "sync" are not canonical; resolved: use **Media Source** for the configuration and **Media Import** for the one-way operation.
- "Media Server Library" is not canonical; resolved: use **Media Source** for origins of media availability and **Library** for club-owned collections.
- "External Source" was replaced by **Metadata Provider** for catalogs such as TMDB or Hardcover.
- "Automation Service" and "Request Profile" are not canonical; resolved: the upstream system, the connection details, and the request-side settings are all attributes of a **Media Source**. An `radarr` or `sonarr` **Media Source** is both an import source and a request destination; a `filesystem` **Media Source** is import-only.
- **Pending Content Request**, **Requested Content Request**, **Available Content Request**, and **Failed Content Request** are not canonical: a **Content Request** has no stored status and is not subtyped by status. The displayed **Content Request Status** and its **Content Request Status Group** *are* canonical, but as *derived read-model values* computed at read time from the **Content**'s **Media** and its **Media Source Requests** — vocabulary, not a stored attribute.
- The work a request-capable **Media Source** does for one piece of **Content** is a first-class concept tracked as a **Media Source Request**. A **Media Source Request** is shared by every **Content Request** for that **Content**; it is not user-scoped. "Request Attempt" was an earlier working name; the canonical term is **Media Source Request**.
- "Request Media" is not a canonical action; resolved: **Request Content** is the user action that creates a **Content Request**. It is independent of **Add to Library** — adding **Content** to a **Library** does not create a **Content Request**.
- "User settings" may appear where the domain means **User Preferences**; resolved: the canonical term is **User Preferences**.
- "Episode" is ambiguous across content types; resolved: use **TV Show Episode** for numbered parts of **TV Show** content.
- External provider episode IDs are not the canonical identity for **TV Show Episodes**; resolved: a **TV Show Episode** is identified within a **TV Show** by season number and episode number.
- Specials are not modeled as **TV Show Episodes**; resolved: a **TV Show Episode** season number starts at 1.
- Radarr and Sonarr are **Media Source Types** that both accept **Media Source Requests** (WatchClub asks them to make content available) and serve as import sources (WatchClub imports the resulting **Media**). One **Media Source** of these types covers both directions of the integration. `chaptarr` is a planned third request-capable type (for **Book** content) and is not yet implemented; the glossary keeps it to document the intended direction, not a live type. Because no request-capable **Book** source exists, **Request Content** today serves only **Movies** and **TV Shows**; the **Book** fan-out is intended design, not current behaviour.
- "Play Media" and "Play Video" are not canonical member actions; resolved: use **Play Library Item** for member-facing playback and reserve **Media** and **Video** for what is selected to play.
- "Video data" is not canonical; resolved: when choosing among **Videos**, describe the visible **Video Track**, **Audio Track**, and **Text Track** details.
- "Player Session" and "HLS Session" are technical names for parts of playback, but the domain concept is **Playback Session**.
- **Playback Session** is distinct from **Watch Progress**; resolved: a Playback Session records one Player visit, while Watch Progress records how far a **User** has got through a **Movie** or **TV Show Episode** overall and whether they finished it.
- **Playback Session** is not a club-scoped or library-scoped concept; resolved: it is scoped to the **User** for one **Player** visit, and the selected **Media** lives on each **Playback** inside it.
- "Stream" and "HLS Stream" are technical names for the runtime state of one media file being played; the domain concept is **Playback** (one **Media** being played inside a **Playback Session**).
- "Playback probe" and "start-of-session probe" are not canonical; resolved: playback uses stored technical details, refreshed only by re-running a **Media Import** with **Refresh Metadata** on.
- "Media Import Result" is not canonical; resolved: per-file outcomes are not persisted today, only the **Media Import**'s overall **Media Import Status**.
- The second phase of a **Media Import** is the **ingest phase** (formerly called the "processing phase"); resolved: the two phases are the **scan phase** and the **ingest phase**. This is distinct from the **Media Import Status** value Processing, which is a separate axis (the whole import being in progress) and keeps its name.
