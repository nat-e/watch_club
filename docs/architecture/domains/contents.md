# Contents

The [server's contents module](../../../apps/server/src/domain/contents), with the structs that help understand it and the private functions that carry its main flow. Its functions all take the database pool and the Metadata Providers, and return their errors in a `Result`: the tree leaves them out.

```text
struct Content  // a Content as its page shows it, in one Locale
├── id: ContentId
├── external_content_id: ExternalContentId
├── title: String
├── original_title: String
├── original_language: Option<String>  // ISO 639-1
├── overview: Option<String>
├── poster: Option<Image>
├── backdrop: Option<Image>
├── release_date: Option<Date>
├── genres: Vec<Genre>
├── rating: Option<f32>  // out of 10, None when too few people voted
├── trailer_url: Option<String>  // YouTube
├── credits: Vec<Credit>  // director, actors, authors…, in display order
├── runtime_seconds: Option<i32>  // when it has one Media, such as a Movie
└── media_group_count: i32  // such as a TV Show's seasons

struct Media  // in one Locale
├── id: MediaId
├── group_number: Option<i32>  // season
├── number_in_group: Option<i32>  // episode
├── title: Option<String>
├── overview: Option<String>
├── image: Option<Image>
├── release_date: Option<Date>  // tells whether it's out
└── runtime_seconds: Option<i32>

struct SearchResults
├── results: Vec<SearchResult>  // title, date, overview, poster and creators
└── next_page: Option<NonZeroU32>  // None on the last page

enum ExternalContentId  // Movie(TmdbId), TvShow(TmdbId), SportsEvent(SportarrId) or Book(HardcoverId)

fn search(query, scope, page, locale) -> SearchResults  // at the Metadata Provider of the scope

fn get_by_external_id(external_content_id, locale) -> Option<Content>  // saves it the first time, queues a refresh after a day

fn refresh(content_id)  // run by a job

mod image
└── struct Image(Vec<ImageSource>)  // each size the Metadata Provider has, from the narrowest

mod localizations
└── struct Translations<T>  // a title, overview or poster in several languages
    ├── original: Option<T>
    └── translated: Vec<(Language, T)>

mod metadata
├── struct MetadataProviders
│   ├── tmdb: Tmdb
│   │   ├── fn search(query, page, locale) -> SearchResults
│   │   ├── fn fetch_movie(id) -> Option<ContentMetadata>
│   │   └── fn fetch_tv_show(id) -> Option<ContentMetadata>
│   ├── sportarr: Sportarr
│   │   ├── fn search(query, page) -> SearchResults
│   │   └── fn fetch_sports_event(id) -> Option<ContentMetadata>
│   ├── hardcover: Hardcover
│   │   ├── fn search(query, page) -> SearchResults
│   │   └── fn fetch_book(id) -> Option<ContentMetadata>
│   └── fn fetch(external_content_id) -> Option<ContentMetadata>  // private, at the Metadata Provider of its type
└── struct ContentMetadata  // a Content as its Metadata Provider describes it: what saving writes
    ├── id: ExternalContentId
    ├── external_ids: ExternalIds  // every External ID, by catalog
    ├── original_title: String
    ├── original_language: Option<String>
    ├── origin_country: Option<String>
    ├── release_date: Option<Date>
    ├── genres: Vec<Genre>
    ├── rating: Option<f32>
    ├── backdrop: Option<Image>
    ├── texts: ContentTranslations  // titles, overviews, posters and trailers, as Translations
    ├── credits: Vec<CreditMetadata>
    └── media: Vec<MediaMetadata>

mod store
├── fn save(metadata) -> ContentId  // private, in one transaction
├── fn find_by_external_id(external_content_id, locale) -> Option<SavedContent>  // private, with the last time it was saved
└── fn list_media(content_id, locale) -> Vec<Media>  // in order, such as by season and episode
```
