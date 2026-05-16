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
A member who can manage the club, its libraries, members, invitations, and library items.
_Avoid_: Admin, owner

**Club Member**:
A member who can view libraries and add content to them.
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

**Library**:
A named collection of content inside a club that accepts one or more content types.
_Avoid_: Club library, list, shelf, playlist

**Library Item**:
A piece of content included in a library.
_Avoid_: Recommendation, availability, selection

**Add to Library**:
Include content in a library so it is visible to club members.
_Avoid_: Add to club library, add to club, recommend, make available

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
A club admin ends another member’s membership in a club.
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

**Accepted Content Type**:
A **Content Type** that a **Library** allows its **Library Items** to reference.
_Avoid_: Library content type, allowed media type

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
- **Delete Club** removes the **Club**’s **Memberships**, **Invitations**, **Libraries**, and **Library Items**
- A **Club** has zero or more **Libraries**
- A **Library** belongs to exactly one **Club**
- Only **Members** can view a **Club**’s **Libraries** and **Library Items**
- A **Library** has one or more **Accepted Content Types**
- A **Library** must have at least one **Accepted Content Type**
- A **Library** remains one collection of **Library Items** even when it has multiple **Accepted Content Types**
- **Accepted Content Types** are a strict whitelist for which **Content** can become **Library Items** in that **Library**
- An **Accepted Content Type** is a **Content Type**
- Adding an **Accepted Content Type** to a **Library** does not affect existing **Library Items**
- Removing an **Accepted Content Type** from a **Library** removes existing **Library Items** of that **Content Type**, but their **Content** is not deleted; the admin UI displays an inline warning before submitting such removals
- A **Library** contains zero or more **Library Items**
- Any **Member** can add **Library Items** to a **Library** when the **Content** matches one of that **Library**’s **Accepted Content Types**
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
- The **Member** who added a **Library Item** can **Remove from Library** for that item
- If a **Library Item** has no adding **Member**, only a **Club Admin** can **Remove from Library** for it
- Only a **Club Admin** can change a **Library**’s **Accepted Content Types**
- Only a **Club Admin** can **Delete Library**
- **Delete Library** removes the **Library** and its **Library Items**, but not their **Content**

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

> **Dev:** "When a **Member** adds a movie to a **Library**, are they recommending it?"
> **Domain expert:** "No — **Add to Library** creates a **Library Item** so the **Content** is visible to the **Club**."
> **Dev:** "Can they add it to any library?"
> **Domain expert:** "Only if it matches one of the **Library**’s **Accepted Content Types**."

## Flagged ambiguities

- "Invitee" can imply a known person, but an **Invitation** only stores an **Invitee Name** until someone accepts it.
- "Media" is not the canonical term for **Content**.
- "Club Library" may appear where the domain means **Library**; resolved: the canonical term is **Library**.
- "User settings" may appear where the domain means **User Preferences**; resolved: the canonical term is **User Preferences**.
- "Library content type" was discussed as singular; resolved: a **Library** has one or more **Accepted Content Types**.
- "All content types" is not a **Content Type**; resolved: a **Library** explicitly accepts one or more concrete **Accepted Content Types**.
- Adding **Content** to a **Library** creates a **Library Item**; it is not a recommendation or endorsement.
