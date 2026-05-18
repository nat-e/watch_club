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
_Avoid_: list, shelf, playlist

**Library Item**:
A piece of content included in a library.
_Avoid_: Recommendation, availability, selection

**Play Library Item**:
Play media for a library item through WatchClub.
_Avoid_: Stream content, watch media, play media server item

**Download Library Item**:
Download media version for a library item through WatchClub.
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
A content request whose content has at least one media version available in WatchClub.
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

### Contents

**Content**:
A creative work that can be added to a library, such as a movie, TV show, book, video, or podcast.
_Avoid_: Media, title, item, recommendation

**Content Type**:
The kind of content, such as movie, TV show, book, video, or podcast.
_Avoid_: Media type, category

**Media**:
A playable or downloadable unit that belongs to content, such as a movie or a TV show episode.
_Avoid_: Playable item, file, episode item

**Media Version**:
A specific playable or downloadable variant of media available in WatchClub.
_Avoid_: File, stream, copy, media item, MediaVersion

**Episode**:
Media that belongs to TV show content.
_Avoid_: TV media, show item

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
A service that WatchClub can ask to make media available.
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
- A **Member** can **Play Library Item** or **Download Library Item** using **Media Versions** of the **Library Item**’s **Content**
- When multiple **Media Versions** are available for **Play Library Item** or **Download Library Item**, the **Member** chooses one
- A **Library Item** can exist when none of its **Content**’s **Media** has a **Media Version**
- **Add to Library** requests the **Library Item**’s **Content** as a whole
- For **TV Show** content, **Add to Library** requests the entire **TV Show**, not a season or **Episode**
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

### Contents

- A **Movie**, **TV Show**, and **Book** are kinds of **Content**
- A **Content** is identified in a **Metadata Provider** by an **External ID**
- The same real-world work from two **Metadata Providers** may be represented as separate **Content** until explicitly reconciled
- **Content Localization** applies to any **Content**
- A **Content** can have multiple **Content Localizations**
- A **Content** has at most one **Content Localization** per **Locale**
- A **Content** has exactly one **Content Type**
- A **Media** belongs to exactly one **Content**
- A **Content** has one or more **Media**
- A **Movie** has exactly one **Media**
- A **Book** has exactly one **Media**
- A **TV Show** has one or more **Episodes**
- An **Episode** is a kind of **Media**
- A **Media** may have zero or more **Media Versions**
- A **Media Version** belongs to exactly one **Media**
- A **Media** can have multiple **Media Versions** when multiple selectable variants are available

### Automation Services

- An **Automation Service** can be asked to make **Content** available in WatchClub
- An **Automation Service** supports one or more **Content Types**
- Only the **Instance Administrator** can manage **Automation Services**
- **Automation Services** are configured for the WatchClub instance by the **Instance Administrator**
- A **Request Profile** uses exactly one **Automation Service**
- A **Request Profile** can only use an **Automation Service** that supports its **Library**’s **Content Type**
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
> **Dev:** "Can they add it to any library?"
> **Domain expert:** "Only if the **Content** has the same **Content Type** as the **Library**."

## Flagged ambiguities

- "Invitee" can imply a known person, but an **Invitation** only stores an **Invitee Name** until someone accepts it.
- "Media" was previously ambiguous; resolved: **Content** is the creative work, **Library Item** is content included in a **Library**, and **Media** is a playable or downloadable unit belonging to **Content**.
- "Club Library" may appear where the domain means **Library**; resolved: the canonical term is **Library**.
- "Media Server Library" was considered but is no longer part of the domain; resolved: WatchClub does not manage media server libraries separately.
- "Watch Club Media Server" was considered as a term but is no longer part of the domain language; resolved: media versions are simply available in WatchClub.
- External media server integrations were considered but are no longer part of the domain; resolved: WatchClub provides play and download itself.
- "External Source" was replaced by **Metadata Provider** for catalogs such as TMDB or Hardcover.
- Radarr and Sonarr are **Automation Services**, not media servers or metadata providers.
- "Request settings" is not canonical; use **Request Profile** for the library-specific way to request content through an **Automation Service**.
- "Request Media" and "Request Content" are not canonical actions; resolved: **Add to Library** is the user action and it may create **Content Requests**.
- "User settings" may appear where the domain means **User Preferences**; resolved: the canonical term is **User Preferences**.
- "Library content type" is singular; resolved: a **Library** has exactly one **Content Type**.
- "Accepted Content Types" is no longer canonical; resolved: use the **Library**’s **Content Type**.
- Adding **Content** to a **Library** creates a **Library Item**; it is not a recommendation or endorsement.
- An **Invitation** does not identify the **User** who created it; the **Invitee Name** personalizes the link but does not tie it to a known **User** before acceptance.
- "Admin" was used ambiguously; resolved: use **Instance Administrator** for the instance-level user and **Club Admin** for the privileged club membership assigned at club creation; UI may use "Admin" only as a shorthand label for **Club Admin**.
