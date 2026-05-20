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

**Play Library Item**:
Play media for a library item through WatchClub.
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
A content request whose content has at least one video, ebook, or audiobook available in WatchClub.
_Avoid_: Complete request, fulfilled request

**Failed Content Request**:
A content request that WatchClub cannot currently progress.
_Avoid_: Errored request, rejected request

**Add to Library**:
Include content in a library so it is visible to club members.
_Avoid_: add to club, recommend, make available

**Remove from Library**:
Remove a library item from a library without deleting the underlying content.
_Avoid_: Remove from club library, delete content, remove content

**Delete Library**:
Permanently remove a library and its library items without deleting the underlying content.
_Avoid_: Delete club library, remove library

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

**Media Source**:
A configured origin used to import local media into WatchClub.
_Avoid_: Playback source, streaming source, media library, sync source, media server library

**Filesystem Media Source**:
A media source whose origin is one filesystem location.
_Avoid_: Folder media source, disk media source, path source

**Media Source Import**:
One execution that imports media availability from a media source and records discovered, deleted, conflicted, and unmatched media.
_Avoid_: Media Source Sync, Media Scan Run, scan job, scan execution

**Media Source Import Result**:
The outcome for one file or item considered during a media source import.
_Avoid_: Import line, scan result, import log entry

**Video**:
Media that can be played and is attached to a movie or TV show episode.
_Avoid_: Media Version, video version

**Ebook**:
Media that can be read or downloaded and is attached to a book.
_Avoid_: Media Version, digital book copy

**Audiobook**:
Media that can be played and is attached to a book.
_Avoid_: Media Version, audio media version

### Contents

**Content**:
A creative work that can be added to a library, such as a movie, TV show, or book.
_Avoid_: Media, title, item, recommendation

**Content Type**:
The kind of content, such as movie, TV show, or book.
_Avoid_: Media type, category

**TV Show Episode**:
A numbered part of TV show content.
_Avoid_: Episode, TV media, show item

**Movie**:
Content whose content type is movie.
_Avoid_: Film

**TV Show**:
Content whose content type is TV show.
_Avoid_: Show, series

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

### Clubs

- A **Club** is visible only to its **Members**, except through an **Invitation**
- A **Club** has one or more **Members**
- A **Membership** may originate from an **Invitation**
- A **Club** has exactly one **Club Admin**
- A **Club Admin** and a **Club Member** are both **Members**
- The **Club Admin** cannot **Leave Club** or be the target of **Remove Member**
- Only a **Club Admin** can view the full member and invitation list for a **Club**
- A **Club Member** can view only their own **Membership**
- **Leave Club** ends the acting **Club Member**’s **Membership** without removing **Library Items** they added
- **Remove Member** ends another **Member**’s **Membership** without removing **Library Items** they added
- An **Invitation** belongs to exactly one **Club**
- An **Invitation** is created by a **Club Admin** but identifies only its **Club**, not the **User** who created it
- Accepting an **Invitation** creates exactly one **Membership**
- Accepting an **Invitation** creates a **Membership** as a **Club Member**
- Anyone with an **Invitation** link can view the invitation, including the **Club**
- An **Invitation** is link-based and is not tied to a specific **User** before acceptance
- An **Invitation** may have one **Invitee Name**
- An **Expired Invitation** cannot be accepted
- A **Used Invitation** cannot be accepted again
- **Delete Invitation** applies only to an unused **Invitation**
- Only a **Club Admin** can **Delete Club**
- **Delete Club** removes the **Club**’s **Memberships**, **Invitations**, **Libraries**, and **Library Items**
- A **Club** has zero or more **Libraries**
- A **Library** belongs to exactly one **Club**
- Only **Members** can view a **Club**’s **Libraries** and **Library Items**
- A **Library** has exactly one **Content Type**
- A **Club** can have multiple **Libraries** with the same **Content Type**
- A **Library** contains only **Library Items** whose **Content** has the same **Content Type** as the **Library**
- A **Library** contains zero or more **Library Items**
- Any **Member** can add **Library Items** to a **Library** when the **Content** matches that **Library**’s **Content Type**
- **Add to Library** creates a **Library Item**
- A **Library** can contain a given **Content** at most once
- The same **Content** can appear in multiple **Libraries**
- A **Library Item** belongs to exactly one **Library** and references exactly one **Content**
- A **Library Item** is visible to all **Members** of its **Club**
- A **Library Item** is added by a **Member**
- If the adding **Member** later leaves the **Club**, the **Library Item** remains in the **Library**
- If a **User** is deleted, **Library Items** they added remain in their **Libraries** without an adding **Member**
- **Remove from Library** removes a **Library Item** but not its **Content**
- A **Club Admin** can **Remove from Library** for any **Library Item**
- A current **Member** who added a **Library Item** can **Remove from Library** for that item
- A former **Member** cannot **Remove from Library** unless they rejoin the **Club**
- If a **Library Item** has no adding **Member**, only a **Club Admin** can **Remove from Library** for it
- A **Member** can **Play Library Item** and **Download Library Item** only for **Library Items** visible to them in WatchClub
- A **Member** can **Play Library Item** or **Download Library Item** using **Videos**, **Ebooks**, or **Audiobooks** attached to the **Library Item**’s **Movie**, **Book**, or **TV Show Episodes**
- When multiple **Videos**, **Ebooks**, or **Audiobooks** are available for **Play Library Item** or **Download Library Item**, the **Member** chooses one
- A **Library Item** can exist when its **Movie**, **Book**, or **TV Show Episodes** have no **Videos**, **Ebooks**, or **Audiobooks**
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
- **Content Requests** created by the same **Add to Library** may have different **Content Request Statuses**
- A **Library**’s **Content Type** is chosen when the **Library** is created and cannot be changed later
- Only a **Club Admin** can **Delete Library**
- **Delete Library** removes the **Library** and its **Library Items**, but not their **Content**
- Only a **Club Admin** can manage **Request Profiles** for a **Library** in their **Club**
- A **Library** may have zero or more **Request Profiles**
- A **Request Profile** belongs to exactly one **Library**
- A **Library** can have multiple **Request Profiles** that use the same **Automation Service**
- Adding a **Request Profile** to a **Library** does not create **Content Requests** for existing **Library Items**
- Deleting a **Request Profile** deletes its **Content Requests**
- **Add to Library** cannot be repeated for **Content** that is already in the **Library**

### Media

- **Media** is instance-wide
- **Video**, **Ebook**, and **Audiobook** are kinds of **Media**
- A **Library** does not own **Media**
- A **Media Source** is not scoped to a **Library**
- A **Media Source** has exactly one **Content Type**
- A single external system can be represented by multiple **Media Sources** when it provides multiple **Content Types**
- A **Media Source** can be imported manually or by a schedule
- A **Media Source** may represent a filesystem location, an external media server, or an automation service
- A **Filesystem Media Source** is a **Media Source**
- A **Filesystem Media Source** has exactly one filesystem location
- Multiple filesystem locations are represented by multiple **Filesystem Media Sources**
- A **Media Source Import** belongs to exactly one **Media Source**
- A **Media Source Import** discovers instance-wide **Media**
- A **Media Source Import** is retained after it finishes
- A **Media Source Import** records its status and outcome
- A **Media Source Import** has one **Media Source Import Result** for each file or item it considered
- A **Media Source Import** does not create **Media** for files or items it cannot match to **Content**
- A **Media Source Import** keeps existing **Media** when its path is still present but cannot be rematched to **Content**
- A filesystem-backed **Media Source Import** recursively examines its **Media Source**’s selected location
- A **Media Source** is used only to import **Media**, not to play or download it
- A **Media Source Import** identifies **Media** by local filesystem path
- A **Media** has exactly one local filesystem path
- A **Media** path is globally unique
- A **Media Source Import** reports a conflict when it finds an existing **Media** path for a different **Content Type**
- A **Media Source Import** conflict does not replace the existing **Media**
- Moving a file deletes the old **Media** and creates new **Media** at the new path
- A filesystem-backed **Media Source Import** deletes previously discovered **Media** under the source path when that **Media** path is no longer present
- Deleting **Media** does not delete **Content**, **Movies**, **Books**, or **TV Show Episodes**
- A **Media Source Import** uses its **Media Source**’s **Content Type** to choose which **Metadata Provider** can identify discovered files as **Content**
- A **Media Source** for **Book** content can discover both **Ebooks** and **Audiobooks**
- A discovered book file’s format determines whether it becomes an **Ebook** or an **Audiobook**
- Only the **Instance Administrator** can manually trigger a **Media Source Import**
- Only the **Instance Administrator** can configure scheduled **Media Sources**
- A **Video** may be attached to exactly one **Movie** or exactly one **TV Show Episode**
- An **Ebook** may be attached to exactly one **Book**
- An **Audiobook** may be attached to exactly one **Book**

### Contents

- A **Movie**, **TV Show**, and **Book** are kinds of **Content**
- A **Content** is identified in a **Metadata Provider** by an **External ID**
- The same real-world work from two **Metadata Providers** may be represented as separate **Content** until explicitly reconciled
- **Content Localization** applies to any **Content**
- A **Content** can have multiple **Content Localizations**
- A **Content** has at most one **Content Localization** per **Locale**
- A **Content** has exactly one **Content Type**
- A **TV Show** has zero or more **TV Show Episodes**
- A **TV Show** may have zero **TV Show Episodes** when none are known yet
- A **TV Show Episode** belongs to exactly one **TV Show**
- A **TV Show** cannot have two **TV Show Episodes** with the same season number and episode number
- A **TV Show Episode** has a season number greater than or equal to 1
- A **TV Show Episode** has an episode number greater than or equal to 1
- A **Movie** may have zero or more **Videos**
- A **Book** may have zero or more **Ebooks** and **Audiobooks**
- A **TV Show Episode** may have zero or more **Videos**
- A **Video** may be attached to exactly one **Movie** or exactly one **TV Show Episode**
- An **Ebook** or **Audiobook** may be attached to exactly one **Book**
- A **Movie**, **Book**, or **TV Show Episode** can have multiple selectable **Videos**, **Ebooks**, or **Audiobooks**

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
- A **Membership** belongs to exactly one **User** and exactly one **Club**
- A **Club** is created by the **Instance Administrator**, who becomes its **Club Admin**
- The **Club Admin** cannot be replaced
- A **User** cannot accept an **Invitation** to a **Club** where they are already a **Member**
- **Delete Club** does not delete **Content**
- A **User** has one **Preferred Content Localization** for each **Content** when a matching localization exists

## Example dialogue

> **Dev:** "When a **Member** adds a movie to a **Library**, are they recommending it?"
> **Domain expert:** "No — **Add to Library** creates a **Library Item** so the **Content** is visible to the **Club**."
> **Dev:** "Does **Scan Library** refresh one club’s **Library**?"
> **Domain expert:** "No — call the configuration **Media Source**. A **Media Source Import** imports media availability from that source and updates instance-wide **Videos**, **Ebooks**, or **Audiobooks**."

## Flagged ambiguities

- "Invitee" can imply a known person, but an **Invitation** only stores an **Invitee Name** until someone accepts it.
- "Media Version" is no longer canonical; resolved: use **Video**, **Ebook**, or **Audiobook** for concrete playable or downloadable media.
- "Scan Library" is not canonical; resolved: use **Media Source** for the configuration and **Media Source Import** for the operation that discovers instance-wide **Videos**, **Ebooks**, and **Audiobooks**.
- "Sync" is not canonical because it implies two-way synchronization; resolved: use **Media Source Import** for one-way discovery from a **Media Source**.
- "Media type" is ambiguous for imports; resolved: a **Media Source** is configured by **Content Type**, not by media type.
- **Media Source** and **Media Source Import** are distinct; resolved: **Media Source** is the configuration and **Media Source Import** is one execution.
- **Media** identity is its local filesystem path; resolved: **Media Source** is only an import mechanism, not part of **Media** identity or playback.
- **Media** paths are globally unique; resolved: the same local path cannot produce multiple **Media** records.
- Cross-content-type path conflicts do not replace existing **Media**; resolved: the **Media Source Import** reports the conflict and leaves existing **Media** unchanged.
- Unmatched files or items do not create **Media**; resolved: they are recorded only as **Media Source Import Results**.
- Match failure does not delete existing **Media**; resolved: deletion is based on source absence, not rematching failure.
- Missing imported files are deleted rather than retained; resolved: metadata and history live on **Content**, **Movies**, **Books**, and **TV Show Episodes**, not on **Media**.
- **Filesystem Media Source Import** deletion is scoped by path prefix; resolved: an import only deletes missing **Media** whose path is under the source path.
- "Episode" is ambiguous across content types; resolved: use **TV Show Episode** for numbered parts of **TV Show** content.
- External provider episode IDs are not the canonical identity for **TV Show Episodes**; resolved: a **TV Show Episode** is identified within a **TV Show** by season number and episode number.
- Specials are not modeled as **TV Show Episodes**; resolved: a **TV Show Episode** season number starts at 1.
- "Club Library" is not canonical; resolved: the canonical term is **Library**.
- Instance-wide libraries were considered but rejected; resolved: a **Library** belongs to one **Club**.
- "Media Server Library" is not canonical; resolved: use **Media Source** for origins of media availability and **Library** for club-owned collections.
- **Media** is a generic domain concept, but **Video**, **Ebook**, and **Audiobook** are preferred when referring to concrete media.
- **Media** is instance-wide even though **Library** is club-owned.
- "Watch Club Media Server" is not a domain term; resolved: **Videos**, **Ebooks**, and **Audiobooks** are available in WatchClub.
- External media servers such as Jellyfin can be **Media Sources**.
- "External Source" was replaced by **Metadata Provider** for catalogs such as TMDB or Hardcover.
- Radarr and Sonarr can be **Automation Services** when WatchClub asks them to make content available, and **Media Sources** when WatchClub imports already-available media from them.
- "Request settings" is not canonical; use **Request Profile** for the library-specific way to request content through an **Automation Service**.
- "Request Media" and "Request Content" are not canonical actions; resolved: **Add to Library** is the user action and it may create **Content Requests**.
- "User settings" may appear where the domain means **User Preferences**; resolved: the canonical term is **User Preferences**.
- "Library content type" is singular; resolved: a **Library** has exactly one **Content Type**.
- "Accepted Content Types" is no longer canonical; resolved: use the **Library**’s **Content Type**.
- Adding **Content** to a **Library** creates a **Library Item**; it is not a recommendation or endorsement.
- An **Invitation** does not identify the **User** who created it; the **Invitee Name** personalizes the link but does not tie it to a known **User** before acceptance.
- "Admin" was used ambiguously; resolved: use **Instance Administrator** for the instance-level user and **Club Admin** for the privileged club membership assigned at club creation; UI may use "Admin" only as a shorthand label for **Club Admin**.
