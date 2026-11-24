//! TMDB's lookup of a Movie by its ID in another catalog, such as IMDb's.

use anyhow::Context;
use serde::Deserialize;

use super::{Tmdb, TmdbId};

impl Tmdb {
    /// Returns the TMDB ID of the Movie with this IMDb ID, such as `tt0133093`, or None when TMDB
    /// knows no Movie with it.
    pub async fn find_movie_by_imdb_id(&self, imdb_id: &str) -> anyhow::Result<Option<TmdbId>> {
        let found: FindResults = self
            .api
            .get_required(
                "/find/{external_id}",
                &[imdb_id],
                &[("external_source", "imdb_id")],
            )
            .await
            .context("failed to find a Movie by its IMDb ID on TMDB")?;
        Ok(found.movie_results.first().map(|movie| TmdbId(movie.id)))
    }
}

/// What TMDB has with an outside ID, by kind. Only Movies matter here.
#[derive(Deserialize)]
struct FindResults {
    movie_results: Vec<FoundMovie>,
}

#[derive(Deserialize)]
struct FoundMovie {
    id: u32,
}
