# Dev catalog

About 800 MB of free-licensed video clips that seed a dev database with a realistic
Library: about 100 Movies, 2 TV Shows and 5 Sports Events, with files in many formats.
Each file is a clip of 1 to 4 minutes of a work under CC BY, CC BY-SA, CC0 or in the public
domain, listed in [ATTRIBUTION.md](ATTRIBUTION.md).

## Seed

`mix setup`, `mix reset` and `wt switch --create` run `mix dev.catalog.seed`. Stop the dev
server first: the seed serves the app on its port while Radarr and Sonarr test their
webhooks. It creates:

- the Users `admin`, the Instance Administrator, `alice` and `bob`, who uses French, all with
  the password `passw0rd`. `wt open` signs in as `WC_DEV_USERNAME`, `admin` in
  `.env.example.dev`.
- this worktree's own Radarr, Sonarr and Sportarr, filled with the files of their folder.
- a Media Source for each folder of `media/`, and their Media Imports, with their Scrubbing
  Thumbnails and Markers.

The first seed of a version of the catalog takes about 5 minutes. It needs Docker, Git LFS,
ffmpeg, the internet and `WC_TMDB_API_KEY` in `.env`. It then saves a snapshot, which later
seeds restore in about 10 seconds, in any worktree, without the internet:

- the catalog's files and the Scrubbing Thumbnails, in the primary worktree's
  `tmp/dev_catalog_snapshots/<name>/`
- the database, in the Postgres database `watch_club_catalog_<name>`
- the data of Radarr, Sonarr and Sportarr, in the Docker volumes `watch_club_catalog_<name>_*`

A snapshot is for one version of the catalog's committed files and of the seed, its `@version`
in `WatchClub.Dev.Catalog`: bump it when you change what the seed creates. A restored database
gets this branch's newer migrations. A branch that lacks one of the snapshot's migrations
seeds from scratch and replaces the snapshot. To seed from scratch, delete the snapshot's
folder.

## Radarr, Sonarr and Sportarr

Each worktree has its own, in the Docker Compose project `<database>_servarrs`, so they match
its database. `mix reset` recreates them and `wt remove` deletes them. Main keeps the ones of
`docker-compose.dev.yml` until you run `mix reset` there. They open without signing in, at:

| App | Port |
| --- | --- |
| Radarr | `WC_PORT` + 20000 |
| Sonarr | `WC_PORT` + 30000 |
| Sportarr | `WC_PORT` + 40000 |

They have no indexer or download client, so a Content Request never downloads anything.

## Files

`media/` is stored with Git LFS. `.lfsconfig` skips it, so clones and CI don't download it.
The seed fetches the files once, and reads them from the snapshot's folder, as copy-on-write
clones of the Git LFS store that worktrees share, so they take no extra disk space on APFS,
Btrfs or XFS. It only knows the committed files.

| Folder | Media Source | Content |
| --- | --- | --- |
| `radarr/` | Radarr | 20 Movies, one file each |
| `sonarr/` | Sonarr | Bonanza: 12 public-domain episodes over 2 seasons |
| `sportarr/` | Sportarr | 4 Sports Events, one file each |
| `movies/` | filesystem | 77 Movies, more copies of 5 of Radarr's, and Unmatched Media |
| `tv/` | filesystem | BBS: The Documentary |
| `sports/` | filesystem | WRC Croatia Rally 2024, in two files |

## What to test where

| Feature | Where |
| --- | --- |
| Browse, filters, Ratings, French overviews | the public-domain classics in `movies/`, such as The Kid or Sherlock Jr., have many votes and French overviews; the recent shorts mostly don't |
| Choosing between copies, and formats | Big Buck Bunny: 12 copies of the same clip, from AVI Xvid to 4K HDR10 and AV1 |
| HDR, Dolby Vision, 8K | Sol Levante and Big Buck Bunny (4K HDR10), Cosmos Laundromat (Netflix HDR grade), Charge (Dolby Vision 8.1), The Daily Dweebs (8K) |
| Lossless 5.1 audio | Caminandes: Llama Drama (FLAC 5.1) |
| Embedded subtitles | Sintel, Tears of Steel, Cosmos Laundromat, Spring, Charge (English and French) |
| Sidecar subtitles | 096 (`.en`, `.fr.forced`), Big Buck Bunny's AVI (`.en.default`, `.fr.forced`, a Windows-1252 `.es`) and WebM (`.en.vtt`) |
| Unsupported subtitles | Big Buck Bunny: `mov_text` in its MP4, PGS and VobSub in its "three audio tracks" MKV |
| Several Audio Tracks, commentary, no language | Big Buck Bunny's "three audio tracks" MKV |
| No audio | Man with a Movie Camera, Intolerance, The Great White Silence |
| Rotation, variable frame rate, interlacing | Big Buck Bunny's MOV and TS |
| Credits | Coffee Run, Glass Half, Wing It!, Butterflies and Little Tombstone end on their credits, with a Credits chapter |
| Markers from chapters | Big Buck Bunny's 1080p MKV (Intro, Recap, Credits), its M4V (French chapter names), BBS's Baud (2) and Compression |
| Intro found from shared audio | BBS: every episode but Compression opens with the same 20 s |
| A TV Show Episode in two files, and a copy holding both | BBS: Baud (1), Baud (2), and Baud |
| A file holding two TV Show Episodes | BBS: Make It Pay + FidoNet |
| Incomplete TV Show, several seasons | BBS misses No Carrier; Bonanza misses most episodes of its 2 seasons |
| A Movie in two files | Elephants Dream's cd1 and cd2, which import as copies until WC-105 |
| A Sports Event in two files | WRC Croatia Rally 2024's Friday and Saturday, which import as copies until WC-104 |
| Very short videos | Norisring (11 s), Mexico City ePrix (24 s) |
| A long video | Orang-U: An Ape Goes to College (47 min) |
| Unmatched Media and Manual Match | Sheep Possible, Bye Bye Birdy and Wormdog |

## Change the catalog

`manifest/*.exs` lists each file: the work it is cut from, its clips and its encoding. `mix
dev.catalog.build` builds the files that `media/` lacks and rewrites `ATTRIBUTION.md`; its
documentation describes the manifests. It needs ffmpeg, and for some files `dovi_tool`,
`mkvmerge` and Subtitle Edit's `seconv`.

Add files rather than replace them: Git LFS keeps every version of a file forever, and GitHub
Free gives 10 GiB of storage in total. To build a file again, delete it first. Use only works
under CC BY, CC BY-SA, CC0 or in the public domain, never NC or ND.
