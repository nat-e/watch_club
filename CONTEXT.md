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
A one-time link created by a **Club Admin** that lets one person join a club.
_Avoid_: Invite, invitation code

**Invitee Name**:
The display name written on an invitation to personalize it before anyone accepts it.
_Avoid_: Invitee, recipient

**Expired Invitation**:
An invitation that can no longer be accepted because its acceptance window has passed.
_Avoid_: Invalid invitation, stale invitation

**Used Invitation**:
An invitation that has already created a membership and cannot be accepted again.
_Avoid_: Accepted invitation, redeemed invitation

**Delete Invitation**:
Remove an unused invitation so its link can no longer be accepted.
_Avoid_: Revoke invitation, cancel invitation

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
A request to make a library item’s content available through one request profile.
_Avoid_: Media Request, Request Content, Request Media, download request, fetch request, acquisition request

**Content Request Status**:
The progress of a content request toward making content available.
_Avoid_: Request state, automation status

**Pending Content Request**:
A content request that WatchClub has created but has not confirmed as accepted by an automation service.
_Avoid_: Queued request, waiting request

**Requested Content Request**:
A content request accepted by an automation service.
_Avoid_: Sent request, grabbed request

**Available Content Request**:
A content request whose requested content has at least one **Media** file available in WatchClub.
_Avoid_: Complete request, fulfilled request

**Failed Content Request**:
A content request that WatchClub cannot currently progress.
_Avoid_: Errored request, rejected request

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

**Media Type**:
The kind of media, either video, ebook, or audiobook.
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

**Ebook**:
Media that can be read or downloaded and is attached to a book.
_Avoid_: Media Version, digital book copy

**Audiobook**:
Media that can be played and is attached to a book.
_Avoid_: Media Version, audio media version

**Video Track**:
A persisted visual stream within a video.
_Avoid_: Stream metadata, playback option

**Audio Track**:
A persisted audio stream within a video.
_Avoid_: Stream metadata, playback option

**Text Track**:
A persisted subtitle or caption track for a video.
_Avoid_: Subtitle track, caption track, stream metadata

**Media Import Configuration**:
A reusable configuration for importing media from one source.
_Avoid_: Media Source, playback source, streaming source, media library, sync source

**Media Import Source Type**:
The kind of source a media import configuration imports from.
_Avoid_: Media type, content type, provider type

**Media Import**:
One execution of a media import configuration.
_Avoid_: Media Source Import, Media Scan Run, scan job, scan execution, sync

**Refresh Metadata**:
A media import option that re-evaluates existing media instead of skipping it.
_Avoid_: Force refresh, rescan existing media

**Refresh Media Metadata**:
Re-evaluate stored technical details for existing media.
_Avoid_: Playback probe, start-of-session probe

**Media Import Status**:
The overall progress or outcome of a media import.
_Avoid_: Media Import Result, import summary, run result, scan result

**Media Import Result**:
The outcome for one file considered or deleted during a media import.
_Avoid_: File Import Result, import line, import log entry

**Media Import Result Status**:
The outcome category assigned to a media import result.
_Avoid_: File Import Result Status, import state, scan status, file status

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

### Automation Services

**Automation Service**:
A service that WatchClub can ask to make content available.
_Avoid_: Acquisition service, media server, metadata provider, download client

**Request Profile**:
A configuration of how a library can request content through an automation service.
_Avoid_: Request target, request settings, automation settings, service settings

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
- An **Invitation** belongs to exactly one **Club**
- An **Invitation** is link-based and is not tied to a specific **User** before acceptance
- An **Invitation** may have one **Invitee Name**
- Accepting an **Invitation** creates exactly one **Membership** as a **Club Member**
- An **Expired Invitation** cannot be accepted
- A **Used Invitation** cannot be accepted again
- **Delete Invitation** applies only to an unused **Invitation**
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
- A **Member** can **Play Library Item** or **Download Library Item** only for **Library Items** visible to them in WatchClub
- A **Member** starts playback through **Play Library Item**, not by playing **Media** or **Video** directly
- **Play Library Item** opens the **Player** after exactly one **Media** file has been selected
- **Play Library Item** from outside the **Player** creates a **Playback Session** and its first **Playback** for the selected **Media** when the **Player** opens, before playback succeeds
- While the **Player** is open, advancing to another **Media** (for example the next **TV Show Episode**) creates a new **Playback** on the same **Playback Session**
- Initially, **Playbacks** are created only for **Video** **Media**
- A **Playback Session** is started by exactly one **User**
- A **Playback Session** has zero or more **Playbacks** over its lifetime
- A **Playback** belongs to exactly one **Playback Session** and references exactly one **Media**
- Only the starting **User** and the **Instance Administrator** can access a **Playback Session** or any of its **Playbacks**
- A **User** can start a **Playback** for **Media** only when at least one visible **Library Item** references the **Content** attached to that **Media**
- For **Media** attached to a **TV Show Episode**, playback access comes from visibility of the parent **TV Show** as a **Library Item**
- Playback availability is based on whether the **Content** is visible to the **User**, not on one selected **Club** or **Library** context
- The **Instance Administrator** can start a **Playback** for any **Media**
- A **Playback** can continue even if the **User** loses access to the **Content** after it starts
- Losing access to **Content** prevents future **Playbacks** but does not end an existing **Playback**
- A **Playback Session** is not scoped to a **Club**, **Library**, or **Library Item**
- A **Playback** is current while it has not ended; it ends when the **Player** closes, when another **Playback** starts on the same **Playback Session**, or when WatchClub marks it inactive after the **Player** stays paused without interaction long enough
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
- **Add to Library** requests the **Library Item**’s **Content** as a whole
- For **TV Show** content, **Add to Library** requests the entire **TV Show**, not a season or **TV Show Episode**
- **Add to Library** creates one **Content Request** for each **Request Profile** configured on the **Library**
- **Add to Library** creates no **Content Requests** when the **Library** has no **Request Profiles**
- **Add to Library** creates the **Library Item** even when one or more **Content Requests** cannot make progress
- A **Content Request** belongs to exactly one **Library Item**
- A **Content Request** uses exactly one **Request Profile**
- A **Library Item** has at most one **Content Request** for a given **Request Profile**
- A **Content Request** has exactly one **Content Request Status**
- A **Content Request Status** is **Pending Content Request**, **Requested Content Request**, **Available Content Request**, or **Failed Content Request**
- Only a **Club Admin** can **Delete Library**
- **Delete Library** removes the **Library** and its **Library Items**, but not their **Content**
- Only a **Club Admin** can **Delete Club**
- **Delete Club** removes the **Club**’s **Memberships**, **Invitations**, **Libraries**, and **Library Items**, but not **Content** or **Media**
- Only a **Club Admin** can manage **Request Profiles** for a **Library** in their **Club**
- A **Library** may have zero or more **Request Profiles**
- A **Request Profile** belongs to exactly one **Library**
- A **Library** can have multiple **Request Profiles** that use the same **Automation Service**
- Adding a **Request Profile** to a **Library** does not create **Content Requests** for existing **Library Items**
- Deleting a **Request Profile** deletes its **Content Requests**
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
- A **Video** is attached to exactly one **Movie** or exactly one **TV Show Episode**
- A **Video** has one or more **Video Tracks**
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
- A **Movie**, **Book**, or **TV Show Episode** can have multiple selectable **Videos**, **Ebooks**, or **Audiobooks**

### Media Imports

- Only the **Instance Administrator** can manage **Media Import Configurations**
- A **Media Import Configuration** is not scoped to a **Library**
- A **Media Import Configuration** is used only to import **Media**, not to play or download it
- A **Media Import Configuration**’s name is calculated from its configuration
- A **Media Import Configuration**’s **Content Type**, **Media Type**, and **Media Import Source Type** cannot be edited after creation
- A filesystem **Media Import Configuration**’s filesystem location can be edited after it has past **Media Imports**
- A **Media Import Configuration** can be disabled to pause scheduled imports
- A disabled **Media Import Configuration** can still be imported manually
- A disabled **Media Import Configuration** can be enabled again
- Deleting a **Media Import Configuration** does not delete **Media** or past **Media Imports**
- A **Media Import Configuration** has exactly one **Content Type**, one **Media Type**, and one **Media Import Source Type**
- Valid **Media Import Configuration** combinations are Movie and Video, TV Show and Video, Book and Ebook, and Book and Audiobook
- A **Media Import Configuration** filters out files that do not match its **Media Type**
- A **Media Import Configuration** uses its **Content Type** to choose which **Metadata Provider** identifies discovered files
- A **Media Import Configuration** may have a schedule, but can also be imported manually without one
- A **Media Import Configuration** has attributes specific to its **Media Import Source Type**
- A **Media Import Source Type** may represent a filesystem location, an external media server, or an automation service
- A filesystem **Media Import Configuration** has exactly one filesystem location
- Filesystem locations may overlap across **Media Import Configurations**
- Multiple **Media Import Configurations** can have the same filesystem location, **Content Type**, and **Media Type**
- **Book** content can be imported through separate **Media Import Configurations** for **Ebook** and **Audiobook** media types
- A single external system can be represented by multiple **Media Import Configurations** when it provides multiple **Content Types**
- A **Media Import** is started from one **Media Import Configuration**
- A manual trigger creates a Pending **Media Import**
- A **Media Import** records whether it was triggered manually or by a schedule, but not which **Instance Administrator** triggered it
- A past **Media Import** remains after its **Media Import Configuration** is deleted
- A **Media Import** keeps a snapshot of the **Media Import Configuration** that ran
- A **Media Import** has **Refresh Metadata** off by default
- A **Media Import** has one **Media Import Status**: Pending, Processing, Completed, or Failed
- A **Media Import Configuration** can have at most one Processing **Media Import** at a time
- A **Media Import** is best-effort per file
- A **Completed** **Media Import** may have **Media Import Results** with No Match or Failed statuses
- A **Failed** **Media Import** is one that cannot finish processing its source
- A **Media Import** creates **Media Import Results** for processed candidate files and deleted **Media**
- A **Media Import Result** belongs to exactly one **Media Import**
- A **Media Import Result** has one **Media Import Result Status**: Created, Updated, Deleted, No Match, or Failed
- A No Match **Media Import Result Status** means a candidate file matched the **Media Type** but could not be confidently matched to **Content** or a **TV Show Episode**
- Files filtered out by **Media Type** do not create **Media Import Results**
- Hidden files and hidden folders are ignored by filesystem imports and do not create **Media Import Results**
- Filesystem imports do not follow symbolic links
- A filesystem import recursively examines its **Media Import Configuration**’s filesystem location
- A **Media Import** creates **Media** only for files with a local filesystem path accessible to WatchClub
- A **Media Import** inspects local files before creating **Videos**, **Ebooks**, or **Audiobooks**
- **Playback Sessions** use the stored technical details of **Media**
- **Play Library Item** does not refresh technical details before opening the **Player**
- **Refresh Media Metadata** can update stored technical details outside the playback start flow
- A filesystem import discovers sidecar **Text Tracks** for **Videos**, without creating separate **Media** for those sidecar files
- A **Media Import** may create missing **Content** when a **Metadata Provider** confidently identifies it
- Content created by a **Media Import** includes all available **Content Localizations**
- A **Media Import** may create a missing **Movie** or **Book** before creating **Media** for it
- When a **Media Import** identifies a video file as an episode of an unknown **TV Show**, it creates the **TV Show** and all known regular **TV Show Episodes** together before creating the **Video**
- When a **Media Import** needs a missing **TV Show Episode** for an existing **TV Show**, it refreshes the **TV Show** as a whole
- **Media Imports** exclude specials when creating **TV Show Episodes**
- A **Media Import** does not create a single **TV Show Episode** on its own
- A **Media Import** does not create **Library Items**
- When **Refresh Metadata** is off, an existing **Media** found again by a **Media Import** is skipped and has no **Media Import Result**
- When **Refresh Metadata** is on, an existing **Media** found again by a **Media Import** has an Updated **Media Import Result Status** even when no stored information changes
- When **Refresh Metadata** is on, a **Media Import** rematches existing **Media** and recreates its generic and concrete media details
- When **Refresh Metadata** is off, a **Media Import** skips existing **Media** even when the same path would now match different **Content**, **Content Type**, or **Media Type**
- A **Media** records its last successful **Media Import**
- Created and Updated **Media Import Results** change which **Media Import** owns deletion tracking for a **Media**
- No Match, Failed, and Deleted **Media Import Results** do not change deletion tracking ownership
- Moving a file deletes the old **Media** and creates new **Media** at the new path
- A filesystem import deletes missing **Media** only when that **Media** is under the configured filesystem location, matches the import’s **Content Type** and **Media Type**, and was last successfully imported by a **Media Import** started from the same **Media Import Configuration**
- Overlapping filesystem imports can run at the same time
- Overlapping filesystem imports do not delete each other’s **Media** unless their current **Media Import** is from the configuration that last successfully imported that **Media**

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

### Automation Services

- An **Automation Service** can be asked to make **Content** available in WatchClub
- An **Automation Service** supports one or more **Content Types**
- Only the **Instance Administrator** can manage **Automation Services**
- **Automation Services** are configured for the WatchClub instance by the **Instance Administrator**
- A **Request Profile** uses exactly one **Automation Service**
- A **Request Profile** can only use an **Automation Service** that supports the **Content Type** it requests
- An **Automation Service** may be used by many **Request Profiles**

### Cross-domain

- A **User** can have memberships in many **Clubs**
- A **Club** is created by the **Instance Administrator**, who becomes its **Club Admin**
- The **Club Admin** cannot be replaced
- A **User** cannot accept an **Invitation** to a **Club** where they are already a **Member**

## Example dialogue

> **Dev:** "Does adding a movie to a **Library** mean the club recommends it?"
> **Domain expert:** "No — **Add to Library** creates a **Library Item** so the **Content** is visible to the **Club**."
> **Dev:** "Where do playable files come from?"
> **Domain expert:** "An **Instance Administrator** defines a **Media Import Configuration**, and each **Media Import** discovers instance-wide **Media** without adding anything to club **Libraries**."

## Flagged ambiguities

- "Admin" was used ambiguously; resolved: use **Instance Administrator** for the instance-level user and **Club Admin** for the privileged club membership assigned at club creation.
- "Invitee" can imply a known person, but an **Invitation** only stores an **Invitee Name** until someone accepts it.
- "Club Library" is not canonical; resolved: the canonical term is **Library**.
- "Media Version" is not canonical; resolved: use **Media** for the local file and **Video**, **Ebook**, or **Audiobook** for concrete media.
- **Media Type** and **Content Type** are distinct; resolved: **Media Type** classifies **Media**, while **Content Type** classifies **Content**.
- "Scan Library", "Media Source", and "sync" are not canonical; resolved: use **Media Import Configuration** for the configuration and **Media Import** for the one-way operation.
- "Media Server Library" is not canonical; resolved: use **Media Import Configuration** for origins of media availability and **Library** for club-owned collections.
- "External Source" was replaced by **Metadata Provider** for catalogs such as TMDB or Hardcover.
- "Request settings" is not canonical; use **Request Profile** for the library-specific way to request content through an **Automation Service**.
- "Request Media" and "Request Content" are not canonical actions; resolved: **Add to Library** is the user action and it may create **Content Requests**.
- "User settings" may appear where the domain means **User Preferences**; resolved: the canonical term is **User Preferences**.
- "Episode" is ambiguous across content types; resolved: use **TV Show Episode** for numbered parts of **TV Show** content.
- External provider episode IDs are not the canonical identity for **TV Show Episodes**; resolved: a **TV Show Episode** is identified within a **TV Show** by season number and episode number.
- Specials are not modeled as **TV Show Episodes**; resolved: a **TV Show Episode** season number starts at 1.
- Radarr and Sonarr can be **Automation Services** when WatchClub asks them to make content available, and can be used by **Media Import Configurations** when WatchClub imports already-available media from them.
- "Play Media" and "Play Video" are not canonical member actions; resolved: use **Play Library Item** for member-facing playback and reserve **Media** and **Video** for what is selected to play.
- "Video data" is not canonical; resolved: when choosing among **Videos**, describe the visible **Video Track**, **Audio Track**, and **Text Track** details.
- "Player Session" and "HLS Session" are technical names for parts of playback, but the domain concept is **Playback Session**.
- **Playback Session** is distinct from future watch-history concepts; resolved: it records one Player visit, not whether a user has watched a work overall.
- **Playback Session** is not a club-scoped or library-scoped concept; resolved: it is scoped to the **User** for one **Player** visit, and the selected **Media** lives on each **Playback** inside it.
- "Stream" and "HLS Stream" are technical names for the runtime state of one media file being played; the domain concept is **Playback** (one **Media** being played inside a **Playback Session**).
- "Playback probe" and "start-of-session probe" are not canonical; resolved: playback uses stored technical details, and **Refresh Media Metadata** is a separate media operation if needed.
