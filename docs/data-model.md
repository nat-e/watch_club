# Data model

The database, one class diagram per domain. Standard `inserted_at` and `updated_at` columns are left out. A class from another domain shows with its name only.

## Accounts

```mermaid
classDiagram
  class User {
    uuid id
    string username «unique»
    string hashed_password
    datetime confirmed_at
    boolean administrator? «unique when true»
  }
  class UserSettings {
    uuid id
    uuid user_id «unique»
    UserLocale locale
  }
  class UserLocale {
    <<enumeration>>
    en_US
    fr_FR
  }
  class InvitationCode {
    uuid id
    string code «unique»
    integer max_uses
    integer uses
    datetime expires_at
  }
  class Token {
    string jti «primary key»
    string subject
    string purpose
    datetime expires_at
    map extra_data
  }
  UserSettings "1" --> "1" User
```

## Instance

```mermaid
classDiagram
  class InstanceSettings {
    uuid id
    string name
    boolean singleton «unique»
  }
```

## Contents

```mermaid
classDiagram
  class Content {
    uuid id
    ContentType type
    ExternalIdSource external_id_source
    string external_id
    string original_title
    string original_language
    string origin_country
    date release_date
    Genre[] genres
    float rating
    datetime metadata_refreshed_at
    «unique» type + external_id_source + external_id
  }
  class ContentType {
    <<enumeration>>
    movie
    tv_show
    book
  }
  class Genre {
    <<enumeration>>
    action
    adventure
    animation
    comedy
    crime
    documentary
    drama
    family
    fantasy
    history
    horror
    kids
    music
    mystery
    news
    politics
    reality
    romance
    science_fiction
    soap
    talk
    thriller
    tv_movie
    war
    western
  }
  class ExternalIdSource {
    <<enumeration>>
    tmdb
    hardcover
  }
  class Movie {
    uuid id «same as Content»
    string backdrop_path
  }
  class MovieLocalization {
    uuid id
    uuid movie_id
    string iso_639_1
    string iso_3166_1
    string title
    string overview
    string poster_path
    integer runtime
    CastMember[] cast
    string trailer_url
    «unique» movie_id + iso_639_1 + iso_3166_1
  }
  class TvShow {
    uuid id «same as Content»
    string original_name
    string backdrop_path
    integer tmdb_id «unique»
    integer tvdb_id «unique»
  }
  class TvShowLocalization {
    uuid id
    uuid tv_show_id
    string iso_639_1
    string iso_3166_1
    string title
    string overview
    string poster_path
    CastMember[] cast
    string trailer_url
    «unique» tv_show_id + iso_639_1 + iso_3166_1
  }
  class CastMember {
    <<embedded>>
    string name
    string role
    string profile_path
  }
  class TvShowEpisode {
    uuid id
    uuid tv_show_id
    integer season_number
    integer episode_number
    date air_date
    string still_path
    integer runtime
    «unique» tv_show_id + season_number + episode_number
  }
  class TvShowEpisodeLocalization {
    uuid id
    uuid tv_show_episode_id
    string iso_639_1
    string iso_3166_1
    string title
    string overview
    «unique» tv_show_episode_id + iso_639_1 + iso_3166_1
  }
  class Book {
    uuid id «same as Content»
    string title
    integer hardcover_id «unique»
  }
  Movie "0..1" --> "1" Content
  TvShow "0..1" --> "1" Content
  Book "0..1" --> "1" Content
  MovieLocalization "*" --> "1" Movie
  TvShowLocalization "*" --> "1" TvShow
  TvShowEpisode "*" --> "1" TvShow
  TvShowEpisodeLocalization "*" --> "1" TvShowEpisode
```

## Media Catalog

```mermaid
classDiagram
  class Media {
    uuid id
    string path «unique»
    MediaType type
    uuid content_id
  }
  class MediaType {
    <<enumeration>>
    movie
    tv_show_episode
    ebook
    audiobook
  }
  class Video {
    uuid id «same as Media»
    uuid movie_id
    uuid tv_show_episode_id
    float duration_seconds
    string container
    integer bit_rate
  }
  class VideoTrack {
    uuid id
    uuid video_id
    integer stream_index
    string codec
    integer width
    integer height
    float frame_rate
    integer bit_rate
    boolean default?
  }
  class AudioTrack {
    uuid id
    uuid video_id
    integer stream_index
    string codec
    string language
    string title
    integer channels
    boolean default?
  }
  class TextTrack {
    uuid id
    uuid video_id
    integer stream_index
    string sidecar_path
    string codec
    string language
    string title
    boolean default?
    boolean forced?
  }
  class Ebook {
    uuid id «same as Media»
    uuid book_id
  }
  class Audiobook {
    uuid id «same as Media»
    uuid book_id
  }
  class Content
  class Movie
  class TvShowEpisode
  class Book
  Media "*" --> "0..1" Content
  Video "0..1" --> "1" Media
  Ebook "0..1" --> "1" Media
  Audiobook "0..1" --> "1" Media
  Video "*" --> "0..1" Movie
  Video "*" --> "0..1" TvShowEpisode
  VideoTrack "1..*" --> "1" Video
  AudioTrack "*" --> "1" Video
  TextTrack "*" --> "1" Video
  Ebook "*" --> "1" Book
  Audiobook "*" --> "1" Book
```

## Media Sources

```mermaid
classDiagram
  class MediaSource {
    uuid id
    string name
    MediaSourceType source_type
    MediaType media_type
  }
  class MediaSourceType {
    <<enumeration>>
    filesystem
    radarr
    sonarr
  }
  class FilesystemMediaSource {
    uuid id «same as MediaSource»
    string filesystem_path
  }
  class ServarrMediaSource {
    uuid id «same as MediaSource»
    ServarrFlavor flavor
    string base_url
    string api_key
    integer quality_profile_id
    string quality_profile_name
    string root_folder_path
    string local_root_folder_path
    string webhook_callback_base_url
    string webhook_secret
    integer notification_id
  }
  class ServarrFlavor {
    <<enumeration>>
    radarr
    sonarr
  }
  class MediaImport {
    uuid id
    uuid media_source_id
    MediaImportStatus status
    boolean refresh_metadata?
    boolean triggered_manually?
    datetime finished_at
  }
  class MediaImportStatus {
    <<enumeration>>
    processing
    completed
    failed
    cancelled
  }
  FilesystemMediaSource "0..1" --> "1" MediaSource
  ServarrMediaSource "0..1" --> "1" MediaSource
  MediaImport "*" --> "1" MediaSource
```

## Playbacks

```mermaid
classDiagram
  class PlaybackSession {
    uuid id
    uuid started_by_id
  }
  class Playback {
    uuid id
    uuid session_id
    uuid media_id
    datetime last_active_at
    datetime ended_at
  }
  class User
  class Media
  PlaybackSession "*" --> "1" User : started_by
  Playback "*" --> "1" PlaybackSession : session
  Playback "*" --> "1" Media
```

## History

```mermaid
classDiagram
  class WatchProgress {
    uuid id
    uuid user_id
    uuid movie_id
    uuid tv_show_episode_id
    uuid book_id
    uuid last_media_id
    float position_seconds
    float duration_seconds
    «unique» user_id + movie_id + tv_show_episode_id + book_id
  }
  class User
  class Movie
  class TvShowEpisode
  class Book
  class Media
  WatchProgress "*" --> "1" User
  WatchProgress "*" --> "0..1" Movie
  WatchProgress "*" --> "0..1" TvShowEpisode
  WatchProgress "*" --> "0..1" Book
  WatchProgress "*" --> "0..1" Media : last_media
```

## Requests

```mermaid
classDiagram
  class ContentRequest {
    uuid id
    uuid content_id «unique»
    uuid requested_by_id
    uuid best_source_request_id
  }
  class RequestSubscriber {
    uuid id
    uuid content_request_id
    uuid user_id
    datetime seen_at
    «unique» content_request_id + user_id
  }
  class MediaSourceRequest {
    uuid id
    uuid content_id
    uuid media_source_id
    MediaSourceRequestStatus status
    float download_progress
    integer external_resource_id
    «unique» content_id + media_source_id
  }
  class MediaSourceRequestStatus {
    <<enumeration>>
    searching
    downloading
    downloaded
    not_released
    needs_attention
  }
  class Content
  class User
  class MediaSource
  ContentRequest "0..1" --> "1" Content
  ContentRequest "*" --> "0..1" User : requested_by
  ContentRequest "0..1" --> "0..1" MediaSourceRequest : best_source_request
  RequestSubscriber "*" --> "1" ContentRequest
  RequestSubscriber "*" --> "1" User
  MediaSourceRequest "*" --> "1" Content
  MediaSourceRequest "*" --> "1" MediaSource
```

## Playlists

```mermaid
classDiagram
  class Playlist {
    uuid id
    uuid owner_id
    string name
    string icon
  }
  class PlaylistItem {
    uuid id
    uuid playlist_id
    uuid content_id
    uuid added_by_id
    datetime added_at
    «unique» playlist_id + content_id
  }
  class PlaylistAccess {
    uuid id
    uuid playlist_id
    uuid user_id
    PlaylistAccessLevel level
    «unique» playlist_id + user_id
  }
  class PlaylistAccessLevel {
    <<enumeration>>
    view
    edit
  }
  class User
  class Content
  Playlist "*" --> "1" User : owner
  PlaylistItem "*" --> "1" Playlist
  PlaylistItem "*" --> "1" Content
  PlaylistItem "*" --> "0..1" User : added_by
  PlaylistAccess "*" --> "1" Playlist
  PlaylistAccess "*" --> "1" User
```

## Conversations

```mermaid
classDiagram
  class Conversation {
    uuid id
    uuid content_id
    uuid recommended_by_id
  }
  class Participant {
    uuid id
    uuid conversation_id
    uuid user_id
    uuid last_read_message_id
    «unique» conversation_id + user_id
  }
  class Message {
    uuid id
    uuid conversation_id
    uuid author_id
    MessageKind kind
    string body
  }
  class MessageKind {
    <<enumeration>>
    recommendation
    text
  }
  class Content
  class User
  Conversation "*" --> "1" Content
  Conversation "*" --> "0..1" User : recommended_by
  Participant "2..*" --> "1" Conversation
  Participant "*" --> "0..1" User
  Participant "*" --> "0..1" Message : last_read_message
  Message "1..*" --> "1" Conversation
  Message "*" --> "0..1" User : author
```

## Activity Feed

```mermaid
classDiagram
  class FeedEvent {
    uuid id
    FeedEventType type
    uuid actor_id
    uuid content_id
    uuid playlist_id
    map data
    string group_key
    datetime occurred_at
    «unique» actor_id + content_id when content_watched
  }
  class FeedEventType {
    <<enumeration>>
    content_watched
    content_requested
    playlist_shared
  }
  class FeedEntry {
    string group_key «primary key»
    datetime latest_at
  }
  class User
  class Content
  class Playlist
  FeedEvent "*" --> "1" FeedEntry : group_key
  FeedEvent "*" --> "1" User : actor
  FeedEvent "*" --> "0..1" Content
  FeedEvent "*" --> "0..1" Playlist
```
