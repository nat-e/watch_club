# Jellyfin library scanning rules relevant to WatchClub Media Import

Research snapshot: Jellyfin `jellyfin/jellyfin` master at `afb4d180d9f9174be754045d30e7388394f21488` (2026-05-20). Source was cloned to `/tmp/jellyfin-src` for this investigation.

This document focuses on movie/TV filesystem imports, TMDb matching, and sidecar subtitles because those map directly to the planned WatchClub filesystem import job.

## High-level model

Jellyfin separates import into two broad phases:

1. **Filesystem resolution** turns files/folders into typed library items (`Movie`, `Series`, `Season`, `Episode`, generic `Video`) using extension lists, folder heuristics, naming regexes, ignore rules, and provider IDs embedded in filenames/folder names.
2. **Metadata refresh** builds a lookup object from the resolved item (`name`, `year`, provider IDs, episode/season numbers), runs local metadata providers (notably NFO), then runs enabled remote providers such as TMDb.

Useful sources:

- `Emby.Server.Implementations/Library/LibraryManager.cs`
- `Emby.Server.Implementations/Library/Resolvers/Movies/MovieResolver.cs`
- `Emby.Server.Implementations/Library/Resolvers/TV/{SeriesResolver,SeasonResolver,EpisodeResolver}.cs`
- `Emby.Server.Implementations/Library/{CoreResolutionIgnoreRule,DotIgnoreIgnoreRule,IgnorePatterns,PathExtensions}.cs`
- `Emby.Naming/Common/NamingOptions.cs`
- `Emby.Naming/Video/*`
- `Emby.Naming/TV/*`
- `MediaBrowser.Providers/Manager/{ProviderManager,MetadataService}.cs`
- `MediaBrowser.Providers/Plugins/Tmdb/*`
- `MediaBrowser.Providers/MediaInfo/MediaInfoResolver.cs`
- `Emby.Naming/ExternalFiles/ExternalPathParser.cs`
- `MediaBrowser.XbmcMetadata/{Providers,Parsers,Savers}/*Nfo*.cs`

Tests cross-checked for examples/regression behavior:

- `tests/Jellyfin.Naming.Tests/Video/{VideoResolverTests,MultiVersionTests,StackTests,ExtraTests}.cs`
- `tests/Jellyfin.Naming.Tests/TV/*Tests.cs`
- `tests/Jellyfin.Naming.Tests/ExternalFiles/ExternalPathParserTests.cs`
- `tests/Jellyfin.Providers.Tests/MediaInfo/{MediaInfoResolverTests,SubtitleResolverTests}.cs`
- `tests/Jellyfin.Common.Tests/Providers/ProviderIdParserTests.cs`
- `tests/Jellyfin.Server.Implementations.Tests/Library/{PathExtensionsTests,SeriesResolverTests,SeasonResolverTests,EpisodeResolverTest}.cs`

## Filesystem discovery and ignore rules

### Resolver pipeline

`LibraryManager.ResolvePath` builds `ItemResolveArgs`, applies ignore rules, enumerates directory children, filters ignored children again, then asks registered resolvers in priority order for the first non-null item. `ResolvePaths` first lets multi-item resolvers process a sibling list as a group; if none handles it, each path is resolved individually.

Key behavior:

- Resolver ignore rules run before any item classification.
- Directory resolution gathers direct child files/folders; physical roots may be flattened and `.mblink` shortcuts may be expanded.
- Multi-item resolution is important for movies/videos because it groups stacks and alternate versions before individual file resolution.

### Built-in ignored paths

`IgnorePatterns` ignores these notable categories case-insensitively:

- Specific art/cache files: `small.jpg`, `albumart.jpg`, `thumbs.db`.
- Samples: `sample.?` through `sample.?????`, `*.sample.?` through `*.sample.?????`, and `sample/` folders.
- Hungarian sample aliases: same treatment for `minta`.
- Metadata/system folders: `metadata`, `ps3_update`, `ps3_vprm`, `extrafanart`, `extrathumbs`, `.actors`, `.wd_tv`, `lost+found`, `subs`, `.snapshots`, `.snapshot`, `.zfs`.
- Trickplay: `*.trickplay`, `*.trickplay/**`.
- Temp recording folders: `TempRec`, `TempSBE`.
- NAS/recycle/system folders: `eaDir`, `@eaDir`, `#recycle`, `@Recycle`, `.@__thumb`, `$RECYCLE.BIN`, `System Volume Information`, `.grab`.
- Unix hidden files/folders: `**/.*`.
- Sync temp files: `*.bts`, `*.sync`.

There is also `.ignore` support: `DotIgnoreIgnoreRule` walks upward from the path to find a `.ignore` file, parses gitignore-style rules, and treats an empty/whitespace-only or fully invalid `.ignore` file as “ignore everything below here”.

`CoreResolutionIgnoreRule` adds domain-specific ignores:

- Application folders are not ignored even if they match generic rules.
- Top-level media folders are not ignored merely because their names match extra-folder names.
- Extra folders such as `trailers`, `extras`, etc. are ignored as normal library items under unsupported parents.
- Theme song files are not resolved as normal audio.

## Video file classification

### Supported video extensions

From `NamingOptions.VideoFileExtensions`:

```text
.001 .3g2 .3gp .amv .asf .asx .avi .bin .bivx .divx .dv .dvr-ms .f4v
.fli .flv .ifo .img .iso .m2t .m2ts .m2v .m4v .mkv .mk3d .mov .mp4
.mpe .mpeg .mpg .mts .mxf .nrg .nsv .nuv .ogg .ogm .ogv .pva .qt .rec
.rm .rmvb .strm .svq3 .tp .ts .ty .viv .vob .vp3 .webm .wmv .wtv .xvid
```

`.disc` is a stub extension. Stub type comes from the token before `.disc`, e.g. `Movie.bluray.disc`, using tokens such as `dvd`, `hddvd`, `bluray`, `brrip`, `bd25`, `bd50`, `vhs`, `HDTV`, `PDTV`, `DSR`.

### DVD/Blu-ray folders and images

`BaseVideoResolver` detects disc folders:

- DVD folder: child directory named `video_ts` containing at least one `.vob`, or child file `video_ts.ifo`.
- Blu-ray folder: child directory named `bdmv`.
- `.iso`/`.img` become `VideoType.Iso`. Jellyfin guesses DVD/Blu-ray ISO by path text (`dvd`, `bluray`) and, if needed, opens the UDF image looking for `VIDEO_TS` or `BDMV`.
- `.strm` is treated as a shortcut video.

### Name and year cleaning

`VideoResolver.Resolve` parses:

- Container extension.
- 3D flags (`3d.sbs`, `hsbs`, `htab`, `mvc`, etc.).
- Extra type (`-trailer`, `-sample`, extra folders, etc.).
- Name and year.

Year extraction recognizes a 1900/2000-year separated by common delimiters. After year extraction, “clean string” regexes remove quality/source/release tokens such as `720p`, `1080p`, `2160p`, `bluray`, `web-dl`, `x264`, `x265`, `dts`, `proper`, `repack`, `limited`, `unrated`, etc.

### Extras

Extra rules come from `NamingOptions.VideoExtraRules` and `ExtraRuleResolver`.

Directory names recognized as extras include:

- `trailers`, `backdrops`, `theme-music`, `behind the scenes`, `deleted scenes`, `interviews`, `scenes`, `samples`, `shorts`, `featurettes`, `extras`, `extra`, `other`, `clips`.

Filename/suffix rules include:

- Filename exactly `trailer`, `sample`, `theme`.
- Suffixes like `-trailer`, `.trailer`, `_trailer`, `- trailer`, `-sample`, `.sample`, `_sample`, `-scene`, `-clip`, `-interview`, `-behindthescenes`, `-deleted`, `-deletedscene`, `-featurette`, `-short`, `-extra`, `-other`.

Movie/Episode resolvers ignore extras as primary media. Extras may later be attached to an owner item.

### Stacking and alternate versions

`VideoListResolver` and `StackResolver` operate on sibling files before individual resolution.

Stacked multipart files are grouped when names match patterns like:

- `Movie cd1`, `Movie cd2`
- `Movie dvd1`, `Movie dvd2`
- `Movie part1`, `Movie part2`
- `Movie pt1`, `Movie pt2`
- `Movie disc1` / `disk1`
- Numeric or alphabetic parts (`1`, `2`, or `a`-`d`)

Rules require matching stack name, same part type, no duplicate part number, and at least two parts.

Alternate versions:

- Movie versions are grouped when all candidate files are in a folder whose name matches the media title and each filename starts with the folder name followed by an eligible suffix (`-`, `_`, `.`, bracketed version text, or cleaned quality/version tokens). Different years prevent grouping.
- Resolution-like suffixes sort higher-quality versions first (`2160p` before `1080p` before `720p`).
- A stacked entry is preferred as the primary version over single-file entries.
- TV episode versions are grouped by parsed episode key, not title: `S{season}E{episode}` or daily date. This means two different files with the same parsed episode number become alternate versions even if their trailing titles differ.

## Movie matching and TMDb provider IDs

### Movie filesystem resolution

`MovieResolver` handles configured movie/homevideo/musicvideo/photo libraries and mixed-content libraries.

Notable movie rules:

- In a `movies` collection, both folders and files can resolve to `Movie`.
- In a folder, if exactly one non-extra video is found and no unrelated photos/subfolders are present, that folder becomes a single movie folder; the movie name is the folder name.
- If multiple videos are present, the multi-item resolver groups stacks/versions or returns multiple items in a mixed folder.
- In mixed-content libraries, folder-level `tvshow.nfo` or `season.nfo`, series parents, and resolver priority prevent obvious TV folders being imported as movies.

### Provider IDs from filenames/folder names

`PathExtensions.GetAttributeValue` parses provider IDs in bracketed/parenthesized/braced attributes:

```text
Movie [tmdbid=618355]
Movie [tmdbid-618355]
Movie {imdbid=tt10985510}
Movie (tvdbid-12345)
```

Rules:

- The attribute must be inside matching `[]`, `{}`, or `()`.
- Separator can be `=` or `-`.
- At least one character must be present before the closing bracket.
- `tmdbid` also falls back to alias `tmdb`.
- `imdbid` additionally scans for an IMDb title ID (`tt` + 7 or 8 digits) anywhere in the remaining string.

Movie-specific behavior:

- For `Movie`/`MusicVideo`, Jellyfin first checks the item name source: folder name for a movie in its own folder, filename for mixed-folder movies.
- If a movie is not in a mixed folder and no TMDb ID was found in the folder, it checks the filename for `tmdbid`.
- IMDb ID is checked against the full media path, so it may be in a parent folder or filename.

TV behavior:

- `SeriesResolver` reads `imdbid`, `tvdbid`, `tvmazeid`, `tmdbid`, `anidbid`, `anilistid`, `anisearchid` from the series folder name.
- `SeasonResolver` reads `tvdbid`, `tvmazeid`, `tmdbid` from the season folder name.
- `EpisodeResolver` reads `imdbid`, `tvdbid`, `tvmazeid`, `tmdbid` from the episode filename without extension.

### NFO metadata as ID source

Local NFO providers are important because they can seed provider IDs before remote providers run.

NFO locations:

- Movie:
  - DVD: `VIDEO_TS/VIDEO_TS.nfo`
  - Movie in own folder: `movie.nfo`
  - DVD/Blu-ray folder: `<folder-name>.nfo`
  - Otherwise: sidecar `<video-basename>.nfo`
- Series: `tvshow.nfo`
- Season: `season.nfo`
- Episode: sidecar `<episode-basename>.nfo`

NFO ID parsing:

- Movie/series `<id>` nodes can carry attributes `TMDB`, `TVDB`, and `IMDB`; if the element text starts with `tt`, it is also treated as an IMDb ID.
- `<uniqueid type="tmdb">123</uniqueid>` maps through registered external ID names.
- Provider tags like `<tmdbid>`, `<imdbid>`, `<tvdbid>` are accepted via `ProviderManager.GetExternalIdInfos`, normalized as provider key + `Id`.
- Additional aliases: `collectionnumber`, `tmdbcolid`, `tmdbcol` -> `TmdbCollection`; `imdb_id` -> `Imdb`.
- URLs inside or after the XML can be parsed:
  - IMDb: `ttNNNNNNN` / `ttNNNNNNNN`
  - TMDb movie: `themoviedb.org/movie/<digits>`
  - TMDb series: `themoviedb.org/tv/<digits>`
  - TVDb: `thetvdb.com/?tab=series&id=<digits>`

### TMDb provider matching order

Jellyfin’s TMDb provider name is `TheMovieDb`.

For movies (`TmdbMovieProvider`):

1. If `Tmdb` provider ID is present, fetch that movie directly.
2. Else if `Imdb` ID is present, use TMDb `find by external id` with IMDb.
3. Else if `Tvdb` ID is present, use TMDb `find by external id` with TVDb.
4. Else search TMDb by cleaned name and year.
5. For metadata refresh, if search by name/year returns results, Jellyfin uses the first result’s TMDb ID.

For series (`TmdbSeriesProvider`):

1. If `Tmdb` provider ID is present, fetch that series directly.
2. Else if `Imdb` ID is present, find by external IMDb ID.
3. Else if `Tvdb` ID is present, find by external TVDb ID.
4. Else search TMDb by cleaned name, language/country, and optional year.
5. Metadata refresh uses the first search result if no ID is available.

For episodes (`TmdbEpisodeProvider`):

- It does not search arbitrary episode names.
- It requires a series TMDb ID from `EpisodeInfo.SeriesProviderIds`.
- It uses season number (`ParentIndexNumber`, defaulting to `1`) and episode number (`IndexNumber`) to fetch `/tv/{series}/season/{season}/episode/{episode}`.
- Multi-episode files fetch each episode in the range and concatenate names/overviews.
- Missing episodes are skipped to avoid large scan-time costs.

Provider manager behavior:

- Enabled providers are selected from library/type options and global metadata options.
- Locked items only run local providers or forced providers.
- During metadata refresh, local metadata providers are tried first; the first local provider with metadata wins the local phase.
- Remote providers then run, and provider IDs found locally are merged into the lookup info before remote calls.
- Remote search results are de-duplicated by overlapping provider IDs.

## TV show and episode parsing

### Series folders

`SeriesResolver` resolves a folder as a series when:

- The library collection type is `tvshows` and the path is not itself configured as a different content type.
- Or the collection type is mixed/null and the folder contains `tvshow.nfo`.
- Or the collection type is mixed/null and heuristics detect season folders or episode-like files.

Series names are derived from the folder name, with cleanup for dotted/underscored names and `Title (Year)` patterns.

### Season folders

`SeasonPathParser` recognizes many localized season words and formats:

- `Season 1`, `Season 01`, `S01`
- Numeric-only season folders when numeric season folders are supported
- `Specials` and `Extras` as season `0`
- Localized tokens including variants of season/series in several languages

It strips the parent series folder name before parsing to avoid false positives.

### Episode files

`EpisodePathParser` uses a long ordered regex list. Supported shapes include:

- `Show S01E02.mkv`, `Show S01.E02.mkv`, `S01 - E02`
- `Show 1x02.mkv`, `Show 01x02.mkv`
- `Show_102.mkv` (season 1, episode 02)
- `Season 1/02 - Title.mkv`
- Anime absolute numbering: `Show - 05 [1080p].mkv`, `[Group] Show [04]`
- Daily shows: `1996.11.14`, `1996-11-14`, `1996_11_14`, `1996 11 14`
- Multi-episode endings: `S01E23-E24-E26`, `02x03-04-15`, `02-04`, while avoiding resolution false positives like `s09e14-1080p`

Safety rules:

- Season numbers `200..1927` and `>2500` are invalidated to avoid parsing resolution-like names as season/episode values.
- If an episode is in a TV context but no season folder/season number is available, Jellyfin assumes season `1` when an episode number or premiere date is known.
- MP4 embedded episode info may override parsed episode/season numbers if enabled in library options.

## Sidecar subtitle matching

### Where Jellyfin looks

`MediaInfoResolver.GetExternalFiles(Video, ...)` only runs for file-protocol videos.

It searches:

1. The video’s containing folder.
2. The video’s internal metadata folder, if it exists.

It removes the video file itself from the candidate list. It does **not** recursively search arbitrary subfolders for subtitles. Note that generic library scanning ignores `subs/` folders, and this sidecar resolver does not look inside `subs/` anyway.

### Supported subtitle extensions

From `NamingOptions.SubtitleFileExtensions`:

```text
.ass .mks .sami .smi .srt .ssa .sub .sup .vtt
```

`.txt` is not a subtitle extension in this code path; Jellyfin uses `.txt` for lyrics.

### Filename prefix rule

A sidecar subtitle matches a video when:

- The subtitle filename without extension starts with the video filename without extension, case-insensitively.
- The subtitle basename is either exactly equal to the video basename, or the next character is a media flag delimiter.
- Jellyfin’s only external-media flag delimiter is `.`.

Examples for `My.Video.mkv`:

- Matches: `My.Video.srt`, `My.Video.en.srt`, `My.Video.Title.en.forced.srt`
- Rejects: `My.Video Sequel.srt`, `Some.Other.Video.srt`, `My.Video.mp3`, `My.Video.png`, `My.Video.txt`

### Token parsing

`ExternalPathParser.ParseFile` receives the suffix after the video basename, e.g. `.Title.en.forced`.

Parsing rules:

- It first validates the extension against subtitle/audio/lyric extensions for the resolver type.
- It walks tokens from right to left using `.` as the separator.
- Flags:
  - Default: token contains `default`.
  - Forced: token contains `forced` or `foreign`.
  - Hearing impaired: token equals `cc`, `hi`, or `sdh`.
- Language:
  - Uses Jellyfin localization to recognize language names/codes.
  - If the culture name contains a hyphen, the BCP-style culture name is used.
  - Otherwise it stores the three-letter ISO language name (`en` -> `eng`, `fr` -> `fre`/`fra`, `hi` -> `hin`).
  - `hi` is ambiguous with the hearing-impaired flag; Jellyfin treats it as Hindi when no language is set and still marks hearing-impaired in the collision branch.
- Remaining unrecognized suffix tokens become the subtitle title, preserving separators.

Examples from tests:

```text
My.Video.en.srt                         -> language eng
My.Video.default.forced.srt             -> default + forced
My.Video.title.en.default.forced.srt    -> title "title", language eng, default + forced
My.Video.sdh.en.title.srt               -> title "title", language eng, hearing impaired
My.Video.Subs for Chinese Audio.eng.srt -> title "Subs for Chinese Audio", language eng
```

### Probing and stream merge behavior

`GetExternalStreamsAsync` probes each matched sidecar with the media encoder.

- If the sidecar contains exactly one stream of the expected type, Jellyfin applies filename flags (`default`, `forced`, hearing-impaired) to that stream and then merges path metadata.
- If the sidecar contains multiple streams, Jellyfin creates one external stream per matching stream but does **not** apply filename flags to all of them; it only fills missing title/language/path via merge metadata.
- Stream metadata wins over filename title/language. Filename title/language only fills missing stream values.
- External stream indices start at the caller-provided `startIndex` and increment across files and streams.
- Errors probing one sidecar are logged and the resolver continues with the rest.

## Transferable implementation guidance for WatchClub

Recommended import precedence:

1. **Explicit provider ID in path or NFO**: trust `[tmdbid=...]`, `[imdbid=...]`, `tvshow.nfo`, `movie.nfo`, etc. before search.
2. **Structured TV parse**: for TV, identify series first, then season/episode from path. Do not create episode media unless the series can be matched.
3. **Name/year search**: use cleaned name + year only when no explicit ID exists. Unlike Jellyfin, consider requiring a confidence threshold or recording `No Match` on ambiguous first-result searches.
4. **Technical probing**: create tracks only after the candidate is accepted as media; sidecar text tracks can be discovered before/alongside probing.

Recommended sidecar rule for v1:

- Match only same-directory sidecars whose basename equals the video basename or starts with `<video-basename>.`.
- Support `.srt`, `.vtt`, `.ass`, `.ssa`, `.sub` initially; add `.smi/.sami/.sup/.mks` if playback/probing supports them.
- Parse suffix tokens right-to-left for `default`, `forced`/`foreign`, `cc`/`hi`/`sdh`, language, and residual title.
- Store language consistently. Jellyfin uses ISO-639-2 in most cases; WatchClub should decide whether `TextTrack.language` stores ISO-639-2 or BCP-47 before importing.

Recommended filtering:

- Skip hidden files/folders, samples, extras folders, recycle/system/NAS folders, and `.ignore`-ignored paths.
- Treat `trailers`, `samples`, `extras`, etc. as non-primary media, at least for v1.
- Decide whether to model multipart stacks and alternate versions. Jellyfin has first-class `AdditionalParts` and `LocalAlternateVersions`; WatchClub currently has a single `Media.path`, so v1 should probably avoid collapsing multiple physical files unless the data model is extended.

Important difference from Jellyfin to consider:

- Jellyfin often takes the first TMDb search result for name/year searches. That is convenient for automatic scans but risky for a job that creates persistent WatchClub content. For WatchClub, an explicit `No Match`/ambiguous result may be better than a silent wrong match.
