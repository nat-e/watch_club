# Media Import Implementation Tickets

## 1. Media domain foundation

**Goal:** Add the core `WatchClub.Media` domain and persistent media model.

Includes:
- `Media`
- `Video`
- `Ebook`
- `Audiobook`
- `VideoTrack`
- `AudioTrack`
- `TextTrack`
- enum types: `MediaType`
- migrations + Ash code interfaces
- policies: instance admin can manage/read all; members only access via library-item flows later

Acceptance:
- Can create/read/delete media and concrete records through domain actions.
- Deleting `Media` deletes concrete media + tracks/details.
- `Media.path` is normalized and globally unique.

## 2. Media import data model

**Goal:** Add import configuration/run/result resources.

Includes:
- `MediaImportConfiguration`
- `MediaImport`
- `MediaImportResult`
- enum types:
  - `MediaImportSourceType`
  - `MediaImportResultStatus`
- Ash StateMachine-backed status on `MediaImport`
- config snapshot on `MediaImport`
- `refresh_metadata`
- last successful import tracking on `Media`
- no actual import processing yet

Acceptance:
- Instance admin can create/update/delete configurations.
- Deleting configuration preserves past imports.
- Manual trigger can create a pending `MediaImport`.
- Duplicate/overlapping configurations are allowed.
- One running import per configuration is enforced.

## 3. Oban setup + import worker skeleton

**Goal:** Add Oban and wire background execution.

Includes:
- dependency/config/migrations
- worker module for `MediaImport`
- transition `Pending → Running → Completed/Failed`
- no real file processing yet, maybe a no-op worker

Acceptance:
- Triggering an import enqueues a job.
- Job updates import status correctly.
- Failed job marks import as `Failed`.

## 4. Filesystem discovery + media probing

**Goal:** Implement filesystem candidate discovery and technical extraction.

Includes:
- recursive filesystem traversal
- skip hidden files/folders
- do not follow symlinks
- filter by `MediaType`
- normalize paths
- inspect files before creating concrete media
- sidecar text-track discovery for videos
- basic probing extraction

Acceptance:
- Given a filesystem config, produces candidate files.
- Filtered files produce no import results.
- Candidate video files include track/sidecar data.
- Existing media is skipped when `refresh_metadata` is false.

## 5. Content matching and media creation

**Goal:** Turn candidates into `Media` + concrete media or `No Match`.

Includes:
- movie matching/creation
- TV show matching/creation/whole-refresh
- book matching/creation
- all content localizations on created content
- create/update media when matched
- no library items created

Acceptance:
- Matched candidates create `Created` results.
- Existing media + refresh off is skipped.
- Existing media + refresh on creates `Updated` result and recreates concrete details.
- No Match creates result and no media.
- TV show imports never create one episode in isolation.

## 6. Deletion pass

**Goal:** Delete missing media according to ownership rules.

Includes:
- delete only under configured filesystem location
- delete only matching current content type + media type
- delete only if last successful import was from same configuration
- create `Deleted` import results

Acceptance:
- Moved files delete old media and create new media.
- Overlapping imports do not delete each other’s media unless ownership rules allow it.
- Deleted media does not delete content/movie/book/show/episode.

## 7. Instance admin UI

**Goal:** Let the Instance Administrator manage and inspect media imports.

Includes:
- settings/admin page section
- list/create/edit/delete configurations
- manual “Import now”
- import status/history
- import result details

Acceptance:
- Admin can configure filesystem imports.
- Admin can run import manually.
- Admin can inspect No Match/Failed results.
- Non-admins cannot access.

## 8. Library item media consumption integration

**Goal:** Use imported media from library item pages/cards.

Includes:
- load available media for movie/book/show episodes
- play/download selection when multiple media exist
- no global media browsing for normal members

Acceptance:
- Members only access media through visible library items.
- Movie item can expose videos.
- Book item can expose ebooks/audiobooks.
- TV show item can expose episode videos.
