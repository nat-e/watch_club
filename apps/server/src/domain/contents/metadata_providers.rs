//! The Metadata Providers, the catalogs that Content comes from. Each has a gateway that calls it
//! for what WatchClub needs, in WatchClub's terms.

mod hardcover;
mod sportarr;
mod tmdb;

pub use self::{
    hardcover::{Hardcover, HardcoverId},
    sportarr::{Sportarr, SportarrId},
    tmdb::{Tmdb, TmdbId},
};

/// The Metadata Providers that the instance finds Content in.
#[derive(Clone, Debug)]
pub struct MetadataProviders {
    /// The Metadata Provider of Movies and TV Shows
    pub tmdb: Tmdb,
    /// The Metadata Provider of Sports Events
    pub sportarr: Sportarr,
    /// The Metadata Provider of Books
    pub hardcover: Hardcover,
}
