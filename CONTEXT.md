# WatchClub

WatchClub is a self-hosted, private, invite-only media server where people can watch and discuss content. Discovery is curated by other people's recommendations, and it invites users to engage about the content.

This glossary covers what this app rebuilds. The full one is the Phoenix app's, `~/dev/watch_club/CONTEXT.md`: copy terms from it when this app grows.

## Language

### Accounts

**User**:
A person with a WatchClub account.
_Avoid_: Account, profile

**Username**:
A user’s unique public name in WatchClub.
_Avoid_: Handle, display name

**Instance**:
One installation of WatchClub, which its host runs for a group of **Users**.
_Avoid_: Server, site

**Instance Name**:
The name **Users** see for the **Instance**, which its host chooses.
_Avoid_: Server name, site name

**Instance Administrator**:
The single user who administers the WatchClub instance.
_Avoid_: Administrator, admin, owner

**Invitation**:
A link the **Instance Administrator** shares so that new people can create their account.
_Avoid_: Invite, invitation code

**Max Uses**:
The most **Users** an **Invitation** can create. Unlimited when unset.
_Avoid_: Use limit, seats, quota

**Redeem Invitation**:
A new person creates their **User** through an **Invitation**, which counts one use against its **Max Uses**.
_Avoid_: Accept invitation, sign up

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

### Contents

**Content**:
A creative work or an event, such as a movie, TV show, sports event, or book.
_Avoid_: Media, title, item, recommendation

**Movie**:
Content whose content type is movie.
_Avoid_: Film

**TV Show**:
Content whose content type is TV show.
_Avoid_: Show, series

**Sports Event**:
Content whose content type is sports event, such as a UFC event or a Formula 1 race. Its metadata comes from sportarr.net, in English only.
_Avoid_: Sport, match, fight, game

**Book**:
Content whose content type is book.
_Avoid_: Volume

**TV Show Episode**:
A numbered part of a **TV Show**, in one of its seasons.
_Avoid_: Episode, TV media, show item

**Content Type**:
The kind of content, such as movie, TV show, sports event, or book.
_Avoid_: Media type, category

**Metadata Provider**:
A catalog where content metadata comes from, such as TMDB, sportarr.net (for **Sports Events**) or Hardcover.
_Avoid_: External source, provider, integration, source

**External ID**:
The identifier of content within one metadata provider.
_Avoid_: Provider ID, remote ID

**Content Localization**:
A **Content**'s texts and poster in one **Locale**, such as its title and overview.
_Avoid_: Translation, localized content

**Genre**:
A kind of story a **Movie** or **TV Show** tells, such as Drama or Comedy.
_Avoid_: Category, tag

**Rating**:
How good people found a **Movie** or **TV Show**: the average of their votes out of 10 on its **Metadata Provider**.
_Avoid_: Score, vote average, grade

**Media**:
What **Users** play inside a **Content**: a **Movie**'s one Media, each **TV Show Episode**, a **Sports Event**.
_Avoid_: Video, file, item

**Media File**:
A file that brings **Media** to the **Instance**, such as a video.
_Avoid_: Media, video file

**Library**:
All the **Content** that is available on the **Instance** and has **Media Files**.
_Avoid_: Catalog, available content, server content

**Browse**:
The WatchClub interface where a **User** looks through the **Library**.
_Avoid_: Discover

## Relationships

### Accounts

- A **User** has exactly one **Username**
- **User Preferences** belong to one **User** and are managed only by that **User**
- **User Preferences** include the user’s preferred **Locale**
- **User Preferences** include the user’s **Preferred Audio Language**, **Preferred Subtitle Language** and **Languages Without Subtitles**
- A new **User** gets subtitles in the language of their **Locale**, except when the audio is already in it
- Every **User** can see every other **User**
- An **Invitation** is the only way a new person joins WatchClub
- Only the **Instance Administrator** creates, changes and deletes **Invitations**
- An **Invitation** can be redeemed for 7 days after its creation, until it reaches its **Max Uses**
- Only new people **Redeem Invitations**: a signed-in **User** never does
- Deleting an **Invitation** keeps the **Users** it created
- The **Instance Administrator** can delete any other **User**, and can't be deleted

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

### Contents

- A **Content** is found at the **Metadata Provider** of its **Content Type** by its **External ID**, which the **Metadata Provider** can change, such as when it deletes a duplicate; different **Content Types** may share the same **External ID**
- A **Content** has exactly one **Content Type**
- A **User** can search for any **Movie** or **TV Show** on TMDB, **Sports Event** on sportarr.net, or **Book** on Hardcover, in the **Library** or not
- Searching for **Movies** leaves out what TMDB flags as videos rather than movies, such as filmed sports events, concerts and compilations: **Sports Events** come from sportarr.net
- Opening a **Content** saves it from its **Metadata Provider**, with its **Media**, and its page then shows what's saved
- A **Content** has a **Content Localization** in every **Locale**: each text in the Locale's language when its **Metadata Provider** has it, else in English, else in its original language
- A **Media** can exist without a **Media File**, such as a **TV Show Episode** that isn't out yet
- A **Book** has no **Media** yet

## Flagged ambiguities

- "Share" means giving access to a **Playlist**; resolved: sending **Content** to people is **Recommend Content**.
