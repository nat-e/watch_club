//! The credits of a Movie or a TV Show at TMDB: its director and its actors.

use serde::Deserialize;

use super::{optional_text, profile};
use crate::domain::contents::{CreditKind, CreditMetadata, ExternalIds};

/// The number of actors a Content's credits keep, after its director
const MAX_ACTORS: usize = 17;

/// The people who made a Content and who are in it.
#[derive(Debug, Deserialize)]
pub(super) struct Credits {
    #[serde(default)]
    cast: Vec<CastMember>,
    #[serde(default)]
    crew: Vec<CrewMember>,
}

impl Credits {
    /// Returns the first director and the first actors, in billing order. A director who acts in
    /// their Movie shows once, as its director.
    pub(super) fn into_metadata(self) -> Vec<CreditMetadata> {
        let director = self
            .crew
            .into_iter()
            .find(|member| member.job == "Director")
            .map(|director| {
                (
                    director.id,
                    CreditKind::Director,
                    director.name,
                    None,
                    director.profile_path,
                )
            });
        let mut cast = self.cast;
        cast.sort_by_key(|actor| actor.order.unwrap_or(u32::MAX));
        let actors = cast.into_iter().take(MAX_ACTORS).map(|actor| {
            (
                actor.id,
                CreditKind::Actor,
                actor.name,
                actor.character,
                actor.profile_path,
            )
        });

        let mut person_ids = Vec::new();
        director
            .into_iter()
            .chain(actors)
            .filter(|(person_id, ..)| {
                let is_new = !person_ids.contains(person_id);
                person_ids.push(*person_id);
                is_new
            })
            .map(
                |(person_id, kind, name, character, profile_path)| CreditMetadata {
                    kind,
                    name,
                    character,
                    photo: profile_path.as_deref().and_then(profile),
                    external_ids: ExternalIds {
                        tmdb: Some(person_id.to_string()),
                        ..ExternalIds::default()
                    },
                },
            )
            .collect()
    }
}

/// An actor, with the character they play.
#[derive(Debug, Deserialize)]
struct CastMember {
    id: u32,
    name: String,
    #[serde(default, deserialize_with = "optional_text")]
    character: Option<String>,
    profile_path: Option<String>,
    /// Their place in the billing, from 0
    order: Option<u32>,
}

/// A person who made a Content, with their job, such as `Director`.
#[derive(Debug, Deserialize)]
struct CrewMember {
    id: u32,
    name: String,
    job: String,
    profile_path: Option<String>,
}
