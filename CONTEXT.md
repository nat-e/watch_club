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
A user’s belonging to a club, including their role within that club.
_Avoid_: Subscription, enrolment

**Role**:
A member’s permission level within a club.
_Avoid_: Rank, status

**Club Admin**:
A member who can manage the club, its club libraries, members, invitations, and library items.
_Avoid_: Admin, owner

**Club Member**:
A member who can view club libraries and add content to them.
_Avoid_: Regular user, participant

**Invitation**:
A one-time link created by a club admin that lets one person join a club with a chosen role.
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

**Club Library**:
A named collection of content inside a club that accepts one or more content types.
_Avoid_: Library, list, shelf, playlist

**Library Item**:
A piece of content included in a club library.
_Avoid_: Recommendation, availability, selection

**Add to Club Library**:
Include content in a club library so it is visible to club members.
_Avoid_: Add to library, add to club, recommend, make available

**Remove from Club Library**:
Remove a library item from a club library without deleting the underlying content.
_Avoid_: Delete content, remove content

**Delete Club Library**:
Permanently remove a club library and its library items without deleting the underlying content.
_Avoid_: Delete library, remove library

**Leave Club**:
A member ends their own membership in a club.
_Avoid_: Quit club, unsubscribe

**Remove Member**:
A club admin ends another member’s membership in a club.
_Avoid_: Delete member, ban

**Delete Club**:
Permanently remove a club and everything that exists only inside it, without deleting content that may be used elsewhere.
_Avoid_: Archive club, close club

### Contents

**Content**:
A creative work that can be added to a club library, such as a movie, TV show, book, video, or podcast.
_Avoid_: Media, title, item, recommendation

**Content Type**:
The kind of content, such as movie, TV show, book, video, or podcast.
_Avoid_: Media type, category

**Movie**:
Content whose content type is movie.
_Avoid_: Film

**TV Show**:
Content whose content type is TV show.
_Avoid_: Show, series

**Book**:
Content whose content type is book.
_Avoid_: Volume

**External Source**:
A third-party catalog where content metadata comes from.
_Avoid_: Provider, integration, source

**External ID**:
The identifier of content within one external source.
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

### Clubs

- A **Club** is visible only to its **Members**, except through an **Invitation**
- A **Club** has one or more **Members**
- A **Membership** may originate from an **Invitation**
- A **Membership** has exactly one **Role**
- A **Club** must always have at least one **Club Admin**
- A **Club Admin** cannot leave, be removed, or lose the **Club Admin** role if that would leave the **Club** without any **Club Admin**
- A **Club Admin** and a **Club Member** are both **Members**
- **Leave Club** ends the acting **Member**’s **Membership** without removing **Library Items** they added
- **Remove Member** ends another **Member**’s **Membership** without removing **Library Items** they added
- An **Invitation** belongs to exactly one **Club**
- An **Invitation** is created by exactly one **Club Admin**
- Accepting an **Invitation** creates exactly one **Membership**
- An **Invitation** grants either the **Club Admin** or **Club Member** role when accepted
- Anyone with an **Invitation** link can view the invitation, including the **Club** and the **Club Admin** who created it
- An **Invitation** is link-based and is not tied to a specific **User** before acceptance
- An **Invitation** may have one **Invitee Name**
- An **Expired Invitation** cannot be accepted
- A **Used Invitation** cannot be accepted again
- **Delete Invitation** applies only to an unused **Invitation**
- Only a **Club Admin** can **Delete Club**
- **Delete Club** removes the **Club**’s **Memberships**, **Invitations**, **Club Libraries**, and **Library Items**
- A **Club** has zero or more **Club Libraries**
- A **Club Library** belongs to exactly one **Club**
- Only **Members** can view a **Club**’s **Club Libraries** and **Library Items**
- A **Club Library** accepts one or more **Content Types**
- A **Club Library** must accept at least one **Content Type**
- Accepted **Content Types** are a strict whitelist for which **Content** can become **Library Items** in that **Club Library**
- Adding an accepted **Content Type** to a **Club Library** does not affect existing **Library Items**
- Removing an accepted **Content Type** from a **Club Library** requires confirmation when existing **Library Items** of that **Content Type** would no longer be accepted; after confirmation those **Library Items** are removed, but their **Content** is not deleted
- A **Club Library** contains zero or more **Library Items**
- Any **Member** can add **Library Items** to a **Club Library** when the **Content**’s **Content Type** is accepted by that **Club Library**
- **Add to Club Library** creates a **Library Item**
- A **Club Library** can contain a given **Content** at most once
- The same **Content** can appear in multiple **Club Libraries**
- A **Library Item** belongs to exactly one **Club Library** and references exactly one **Content**
- A **Library Item** is visible to all **Members** of its **Club**
- A **Library Item** is added by a **Member**
- If the adding **Member** later leaves the **Club**, the **Library Item** remains in the **Club Library**
- If a **User** is deleted, **Library Items** they added remain in their **Club Libraries** without an adding **Member**
- **Remove from Club Library** removes a **Library Item** but not its **Content**
- A **Club Admin** can **Remove from Club Library** for any **Library Item**
- The **Member** who added a **Library Item** can **Remove from Club Library** for that item
- If a **Library Item** has no adding **Member**, only a **Club Admin** can **Remove from Club Library** for it
- Only a **Club Admin** can **Delete Club Library**
- **Delete Club Library** removes the **Club Library** and its **Library Items**, but not their **Content**

### Contents

- A **Movie**, **TV Show**, and **Book** are kinds of **Content**
- A **Content** is identified in an **External Source** by an **External ID**
- The same real-world work from two **External Sources** may be represented as separate **Content** until explicitly reconciled
- **Content Localization** applies to any **Content**
- A **Content** can have multiple **Content Localizations**
- A **Content** has at most one **Content Localization** per **Locale**
- A **Content** has exactly one **Content Type**

### Cross-domain

- A **User** can have memberships in many **Clubs**
- A **Membership** belongs to exactly one **User** and exactly one **Club**
- A **Club** is created by the **Instance Administrator**, who becomes a **Club Admin** of that **Club**
- A **User** cannot accept an **Invitation** to a **Club** where they are already a **Member**
- **Delete Club** does not delete **Content**
- A **User** has one **Preferred Content Localization** for each **Content** when a matching localization exists

## Example dialogue

> **Dev:** "When a **Member** adds a movie to a **Club Library**, are they recommending it?"
> **Domain expert:** "No — **Add to Club Library** creates a **Library Item** so the **Content** is visible to the **Club**."
> **Dev:** "Can they add it to any club library?"
> **Domain expert:** "Only if the **Content Type** is accepted by that **Club Library**."

## Flagged ambiguities

- "Invitee" can imply a known person, but an **Invitation** only stores an **Invitee Name** until someone accepts it.
- "Media" is not the canonical term for **Content**.
- "Library" may appear as shorthand for **Club Library**; resolved: the canonical term is **Club Library**.
- "User settings" may appear where the domain means **User Preferences**; resolved: the canonical term is **User Preferences**.
- "Club Library content type" was discussed as singular; resolved: a **Club Library** accepts one or more **Content Types**.
- Adding **Content** to a **Club Library** creates a **Library Item**; it is not a recommendation or endorsement.
