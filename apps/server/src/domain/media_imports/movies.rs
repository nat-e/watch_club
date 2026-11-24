//! What Movie files hold: Part 1 of their Movie's one Media. Radarr gives each Movie's TMDB ID, and
//! its IMDb ID, which finds the Movie once TMDB no longer knows the first, such as after deleting a
//! duplicate.

use std::collections::HashMap;

use jiff::SignedDuration;
use tracing::Level;

use super::{Holds, ImportedFile, PartReference};
use crate::{
    db::Pool,
    domain::{
        contents::{
            self, ExternalContentId, MediaLookup, MediaType, SavedMedia,
            metadata::MetadataProviders,
        },
        sources::servarr::MovieFile,
    },
};

/// The time after which an import saves a Movie again from TMDB
const REFRESH_AFTER: SignedDuration = SignedDuration::from_mins(15);

/// Returns what each file holds: Part 1 of its Movie, which it saves from TMDB first when it isn't
/// saved or was saved over 15 minutes ago. Calls TMDB for each Movie once, one call at a time, as
/// one Movie can take several.
pub(super) async fn match_files<'a>(
    db: &Pool,
    metadata_providers: &MetadataProviders,
    files: &[&'a MovieFile],
) -> anyhow::Result<Vec<ImportedFile<'a>>> {
    let external_content_ids: Vec<_> = files
        .iter()
        .map(|file| ExternalContentId::Movie(file.tmdb_id))
        .collect();
    let mut movies =
        contents::find_or_save_media(db, metadata_providers, &external_content_ids, REFRESH_AFTER)
            .await?;

    // TMDB no longer knows some TMDB IDs that Radarr has, such as after deleting a duplicate: their
    // Movies are found by their IMDb IDs instead
    let mut replacements = HashMap::new();
    for file in files {
        let id = ExternalContentId::Movie(file.tmdb_id);
        let (Some(MediaLookup::Unknown), Some(imdb_id)) = (movies.get(&id), &file.imdb_id) else {
            continue;
        };
        // A copy of a Movie already looked up
        if replacements.contains_key(&id) {
            continue;
        }
        match metadata_providers.tmdb.find_movie_by_imdb_id(imdb_id).await {
            Ok(Some(tmdb_id)) => {
                replacements.insert(id, ExternalContentId::Movie(tmdb_id));
            }
            Ok(None) => {}
            Err(error) => {
                movies.insert(id, MediaLookup::Failed(error));
            }
        }
    }
    let replacement_ids: Vec<_> = replacements.values().cloned().collect();
    let replacement_movies =
        contents::find_or_save_media(db, metadata_providers, &replacement_ids, REFRESH_AFTER)
            .await?;

    for (id, lookup) in movies.iter().chain(&replacement_movies) {
        if let MediaLookup::Failed(error) = lookup {
            report_failure(id, error);
        }
    }

    Ok(files
        .iter()
        .map(|file| {
            let id = ExternalContentId::Movie(file.tmdb_id);
            let lookup = match replacements.get(&id) {
                Some(replacement) => &replacement_movies[replacement],
                None => &movies[&id],
            };
            let holds = match lookup {
                MediaLookup::Found(media) => movie_parts(media),
                MediaLookup::Unknown => Holds::Nothing,
                MediaLookup::Failed(_) => Holds::Unknown,
            };
            ImportedFile {
                path: &file.path,
                holds,
            }
        })
        .collect())
}

/// Returns what a file of the Movie with these Media holds: Part 1 of its Media, or nothing when it
/// has none.
fn movie_parts(media: &[SavedMedia]) -> Holds {
    let parts: Vec<_> = media
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

/// Logs that the import failed to save the Movie, whose files stay as they were.
fn report_failure(id: &ExternalContentId, error: &anyhow::Error) {
    tracing::event!(
        name: "media_imports.movie.failed",
        Level::WARN,
        content.external_id = %id.external_id(),
        exception.message = %format_args!("{error:#}"),
        "a Media Import failed to save a Movie, whose files stay as they were",
    );
}
