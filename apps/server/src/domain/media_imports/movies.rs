//! What Movie files hold: Part 1 of their Movie's one Media. Radarr gives each Movie's TMDB ID, and
//! its IMDb ID, which finds the Movie once TMDB no longer knows the first, such as after deleting a
//! duplicate.

use std::collections::HashMap;

use jiff::{SignedDuration, Timestamp};
use tracing::Level;

use super::{Holds, ImportedFile, PartReference};
use crate::{
    db::Pool,
    domain::{
        contents::{
            self, ExternalContentId, MediaType, SavedContentMedia,
            metadata::{MetadataProviders, TmdbId},
        },
        sources::servarr::MovieFile,
    },
};

/// The time after which an import saves a Movie again from TMDB
const REFRESH_AFTER: SignedDuration = SignedDuration::from_mins(15);

/// Returns what each file holds: Part 1 of its Movie, which it saves from TMDB first when it isn't
/// saved or was saved over 15 minutes ago. Calls TMDB for each Movie once, and one call at a time,
/// as one Movie can take several.
pub(super) async fn match_files<'a>(
    db: &Pool,
    metadata_providers: &MetadataProviders,
    files: &[&'a MovieFile],
) -> anyhow::Result<Vec<ImportedFile<'a>>> {
    let external_content_ids: Vec<_> = files
        .iter()
        .map(|file| ExternalContentId::Movie(file.tmdb_id))
        .collect();
    let saved = contents::find_media(db, &external_content_ids).await?;

    // The Movie that each TMDB ID from Radarr turned out to be: None when TMDB knows nothing of it,
    // and an error when saving it failed
    let mut movies: HashMap<TmdbId, anyhow::Result<Option<ExternalContentId>>> = HashMap::new();
    for file in files {
        if movies.contains_key(&file.tmdb_id) {
            continue;
        }
        let saved = saved.get(&ExternalContentId::Movie(file.tmdb_id));
        let movie = save_movie(db, metadata_providers, file, saved).await;
        if let Err(error) = &movie {
            tracing::event!(
                name: "media_imports.movie.failed",
                Level::WARN,
                content.external_id = %file.tmdb_id,
                exception.message = %format_args!("{error:#}"),
                "a Media Import failed to save a Movie, whose files stay as they were",
            );
        }
        movies.insert(file.tmdb_id, movie);
    }

    // Read again, as saving added Movies and could change their Media
    let found: Vec<_> = movies
        .values()
        .filter_map(|movie| movie.as_ref().ok().and_then(Option::clone))
        .collect();
    let saved = contents::find_media(db, &found).await?;
    Ok(files
        .iter()
        .map(|file| {
            let holds = match &movies[&file.tmdb_id] {
                Err(_) => Holds::Unknown,
                Ok(None) => Holds::Nothing,
                // Missing when it was deleted meanwhile
                Ok(Some(movie)) => saved.get(movie).map_or(Holds::Unknown, movie_parts),
            };
            ImportedFile {
                path: &file.path,
                holds,
            }
        })
        .collect())
}

/// Saves the file's Movie from TMDB, unless it was saved in the last 15 minutes, and returns its
/// External ID: the TMDB ID that Radarr gives, or else the one TMDB has for its IMDb ID. None when
/// TMDB knows neither.
async fn save_movie(
    db: &Pool,
    metadata_providers: &MetadataProviders,
    file: &MovieFile,
    saved: Option<&SavedContentMedia>,
) -> anyhow::Result<Option<ExternalContentId>> {
    let id = ExternalContentId::Movie(file.tmdb_id);
    if let Some(saved) = saved {
        if saved.refreshed_at < Timestamp::now() - REFRESH_AFTER {
            // Keeps it as it is when TMDB no longer knows it, and the file still matches it
            contents::refresh(db, metadata_providers, saved.content_id).await?;
        }
        return Ok(Some(id));
    }
    if contents::save(db, metadata_providers, &id).await?.is_some() {
        return Ok(Some(id));
    }

    // TMDB no longer knows the TMDB ID that Radarr has, such as after deleting a duplicate
    let Some(imdb_id) = &file.imdb_id else {
        return Ok(None);
    };
    let Some(tmdb_id) = metadata_providers
        .tmdb
        .find_movie_by_imdb_id(imdb_id)
        .await?
    else {
        return Ok(None);
    };
    let id = ExternalContentId::Movie(tmdb_id);
    Ok(contents::save(db, metadata_providers, &id)
        .await?
        .map(|_| id))
}

/// Returns what a file of the Movie holds: Part 1 of its Media, or nothing when it has none.
fn movie_parts(movie: &SavedContentMedia) -> Holds {
    let parts: Vec<_> = movie
        .media
        .iter()
        .filter(|media| media.media_type == MediaType::Movie)
        .map(|media| PartReference {
            media_id: media.id,
            number: 1,
        })
        .collect();
    if parts.is_empty() {
        Holds::Nothing
    } else {
        Holds::Parts(parts)
    }
}
