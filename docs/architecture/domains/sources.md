# Sources

The [server's sources module](../../../apps/server/src/domain/sources), with the structs that help understand it. Its functions take the database pool, the HTTP client or the encryption key, and return their errors in a `Result`: the tree leaves them out.

```text
enum Source  // its Source Type and Media Type never change
├── Filesystem  // a folder on the server
│   ├── id: SourceId
│   ├── media_type: MediaType  // of every file in it
│   └── path: AbsoluteFolder
└── Servarr  // a Radarr, Sonarr or Sportarr app
    ├── id: SourceId
    ├── app: ServarrApp  // Radarr, Sonarr or Sportarr, which tells the Media Type
    └── configuration: ServarrConfiguration

fn list() -> Vec<Source>

fn get(id) -> Option<Source>

fn delete(id)  // its files stay on disk

mod filesystem
├── fn create(media_type, path) -> Source
└── fn update(id, path) -> Source  // gives it another folder

mod servarr  // Radarr, Sonarr and Sportarr apps
├── struct ServarrConfiguration  // without the API key, which WatchClub keeps encrypted
│   ├── url: ApiUrl
│   ├── quality_profile: QualityProfile  // the quality it downloads in
│   ├── root_folder_path: String  // where it downloads, as the app sees it
│   └── local_root_folder_path: Option<AbsoluteFolder>  // the same folder as WatchClub sees it, such as in Docker
├── struct ServarrChoices  // what the Instance Administrator chooses from
│   ├── quality_profiles: Vec<QualityProfile>
│   └── root_folders: Vec<String>
├── fn test_connection(app, url, api_key) -> ServarrChoices  // checks the app and its API key
├── fn test_saved_connection(id, url, api_key) -> ServarrChoices  // with the saved API key when api_key is None
├── fn create(app, configuration, api_key) -> Source
└── fn update(id, configuration, api_key) -> Source  // keeps the saved API key when api_key is None
```
