//! The Metadata Providers, the catalogs that Content comes from. Each has a gateway that calls it
//! for what WatchClub needs, in WatchClub's terms.

mod tmdb;

pub use self::tmdb::Tmdb;

/// The Metadata Providers that the instance finds Content in.
#[derive(Clone, Debug)]
pub struct MetadataProviders {
    /// The Metadata Provider of Movies and TV Shows
    pub tmdb: Tmdb,
}
