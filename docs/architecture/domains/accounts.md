# Accounts

The [server's accounts module](../../../apps/server/src/domain/accounts), with the structs that help understand it. Its functions all take the database pool and return their errors in a `Result`: the tree leaves both out.

```text
mod instance_administrator
├── fn exists() -> bool  // false until Setup
└── fn create(username, password, locale) -> (CurrentUser, SessionToken)  // Setup

mod invitations
├── struct Invitation
│   ├── id: InvitationId
│   ├── code: String  // in the link
│   ├── max_uses: Option<i64>  // None for no limit
│   ├── uses: i64  // the Users it created
│   └── expires_at: Timestamp
├── fn list_redeemable() -> Vec<Invitation>
├── fn create(max_uses) -> Invitation
├── fn update(invitation_id, max_uses) -> Invitation
├── fn delete(invitation_id)
├── fn is_redeemable(code) -> bool  // for the page that redeems it
└── fn redeem(code, username, password, locale) -> (CurrentUser, SessionToken)  // creates the User and signs them in

mod preferences
├── struct UserPreferences
│   ├── locale: Locale  // en-US or fr-FR
│   ├── audio_language: AudioLanguage  // original, en or fr
│   ├── subtitle_language: Option<TrackLanguage>  // en or fr, None for no subtitles
│   └── languages_without_subtitles: BTreeSet<TrackLanguage>
└── fn save(user_id, preferences) -> CurrentUser

mod sessions
├── struct SessionToken(SecretToken)  // keeps a device signed in; the database stores only its hash
├── fn sign_in(username, password) -> (CurrentUser, SessionToken)
├── fn get_current_user(token) -> Option<CurrentUser>  // None once the session ended or expired
├── fn sign_out(token)  // signs out this device
└── fn delete_expired() -> u64  // run by a scheduled job

mod users
├── struct CurrentUser  // the signed-in User, with their User Preferences
│   ├── id: UserId
│   ├── username: String
│   ├── is_instance_administrator: bool
│   └── preferences: UserPreferences
├── struct User  // a User as the list of Users shows them
│   ├── id: UserId
│   ├── username: String
│   ├── is_instance_administrator: bool
│   └── member_since: Timestamp
├── struct Username(String)  // 3 to 30 lowercase letters, digits or underscores
├── struct Password(SecretString)  // a new password, at least 8 characters
├── fn list() -> Vec<User>
├── fn delete(user_id)
├── fn change_password(user_id, current_session, current_password, new_password)  // signs out the User's other devices
├── fn create_password_reset_link(user_id) -> SecretString  // the link's token
├── fn password_reset_username(token) -> Option<String>  // None once the link no longer works
└── fn reset_password(token, password)  // signs the User out everywhere
```
