//! The saved Content: how the database stores a Content's metadata, and reads it back in a Locale.
//!
//! Every Content Type shares the same tables, so saving and reading don't depend on the type.
//! Saving writes each table with one statement, whatever the number of TV Show Episodes, and
//! leaves the rows that didn't change alone.

use anyhow::Context;
use jiff::Timestamp;
use jiff_sqlx::ToSqlx;
use sqlx::types::Json;
use sqlx_otel::QueryAnnotateExt;

use super::{
    Content, ContentId, ContentMetadata, ContentType, Credit, ExternalContentId, Media, MediaType,
};
use crate::{
    db::{Pool, Transaction},
    domain::accounts::preferences::Locale,
};

/// A saved Content, with its texts in one Locale.
pub(super) struct SavedContent {
    pub content: Content,
    /// The last time it was saved from its Metadata Provider
    pub refreshed_at: Timestamp,
}

/// Saves the Content as its metadata describes it, in one transaction: inserts it, or updates what
/// changed, and deletes the credits and Media its Metadata Provider no longer lists. What belongs
/// to a deleted Media, such as its Watch Progress, goes with it.
///
/// Two saves of the same Content at once take turns: the first locks its row until it commits.
pub(super) async fn save(db: &Pool, metadata: &ContentMetadata) -> anyhow::Result<ContentId> {
    let mut transaction = db.begin().await.context("failed to start a transaction")?;

    let content_id = save_content(&mut transaction, metadata).await?;
    save_content_localizations(&mut transaction, content_id, metadata).await?;
    save_credits(&mut transaction, content_id, metadata).await?;
    save_media(&mut transaction, content_id, metadata).await?;

    transaction
        .commit()
        .await
        .context("failed to save the Content")?;
    Ok(content_id)
}

/// Returns the saved Content with this External ID, with its texts in the Locale, or None when
/// nobody opened it yet.
pub(super) async fn find_by_external_id(
    db: &Pool,
    external_content_id: &ExternalContentId,
    locale: Locale,
) -> anyhow::Result<Option<SavedContent>> {
    let content_type = external_content_id.content_type();
    let Some(row) = sqlx::query!(
        r#"
        SELECT c.id, c.original_title, c.original_language, c.release_date, c.genres, c.rating,
            c.backdrop, c.metadata_refreshed_at, l.title, l.overview, l.poster, l.trailer_url,
            media.count AS "media_count!", media.group_count AS "media_group_count!",
            media.runtime_seconds
        FROM contents c
        JOIN content_localizations l ON l.content_id = c.id AND l.locale = $4
        CROSS JOIN LATERAL (
            SELECT count(*) AS count, count(DISTINCT group_number)::integer AS group_count,
                max(runtime_seconds) AS runtime_seconds
            FROM media
            WHERE content_id = c.id
        ) media
        WHERE c.content_type = $1 AND c.metadata_provider = $2 AND c.main_external_id = $3
        "#,
        content_type as ContentType,
        content_type.metadata_provider() as _,
        external_content_id.external_id(),
        locale as Locale,
    )
    .with_operation("SELECT", "contents")
    .fetch_optional(db)
    .await
    .context("failed to find a Content")?
    else {
        return Ok(None);
    };

    let credits = sqlx::query!(
        r#"
        SELECT kind, name, character, photo
        FROM content_credits
        WHERE content_id = $1
        ORDER BY position
        "#,
        row.id as ContentId,
    )
    .with_operation("SELECT", "content_credits")
    .fetch_all(db)
    .await
    .context("failed to find a Content's credits")?
    .into_iter()
    .map(|credit| Credit {
        kind: credit.kind,
        name: credit.name,
        character: credit.character,
        photo: credit.photo.map(|Json(photo)| photo),
    })
    .collect();

    let content = Content {
        id: row.id,
        external_content_id: external_content_id.clone(),
        title: row.title,
        original_title: row.original_title,
        original_language: row.original_language,
        overview: row.overview,
        poster: row.poster.map(|Json(poster)| poster),
        backdrop: row.backdrop.map(|Json(backdrop)| backdrop),
        release_date: row.release_date.map(jiff_sqlx::Date::to_jiff),
        genres: row.genres,
        rating: row.rating,
        trailer_url: row.trailer_url,
        credits,
        // A runtime only makes sense for the Content as a whole when it has one Media
        runtime_seconds: row.runtime_seconds.filter(|_| row.media_count == 1),
        media_group_count: row.media_group_count,
    };
    Ok(Some(SavedContent {
        content,
        refreshed_at: row.metadata_refreshed_at.to_jiff(),
    }))
}

/// Returns the Content's Media in order, such as a TV Show's Episodes by season and episode, with
/// their texts in the Locale. Returns none when there's no such Content.
#[tracing::instrument(skip_all, fields(content.id = %content_id))]
pub async fn list_media(
    db: &Pool,
    content_id: ContentId,
    locale: Locale,
) -> anyhow::Result<Vec<Media>> {
    let media = sqlx::query!(
        r#"
        SELECT m.id, m.group_number, m.number_in_group, l.title, l.overview, m.image,
            m.release_date, m.runtime_seconds
        FROM media m
        JOIN media_localizations l ON l.media_id = m.id AND l.locale = $2
        WHERE m.content_id = $1
        ORDER BY m.group_number, m.number_in_group
        "#,
        content_id as ContentId,
        locale as Locale,
    )
    .with_operation("SELECT", "media")
    .fetch_all(db)
    .await
    .context("failed to list a Content's Media")?;

    Ok(media
        .into_iter()
        .map(|row| Media {
            id: row.id,
            group_number: row.group_number,
            number_in_group: row.number_in_group,
            title: row.title,
            overview: row.overview,
            image: row.image.map(|Json(image)| image),
            release_date: row.release_date.map(jiff_sqlx::Date::to_jiff),
            runtime_seconds: row.runtime_seconds,
        })
        .collect())
}

/// Returns the External ID of the Content with this ID, or None when there's no such Content.
pub(super) async fn external_content_id(
    db: &Pool,
    content_id: ContentId,
) -> anyhow::Result<Option<ExternalContentId>> {
    let row = sqlx::query!(
        "SELECT content_type, main_external_id FROM contents WHERE id = $1",
        content_id as ContentId,
    )
    .with_operation("SELECT", "contents")
    .fetch_optional(db)
    .await
    .context("failed to find a Content")?;

    let Some(row) = row else {
        return Ok(None);
    };
    let external_content_id = ExternalContentId::parse(row.content_type, &row.main_external_id)
        .with_context(|| {
            format!(
                "a saved Content has the invalid External ID {}",
                row.main_external_id
            )
        })?;
    Ok(Some(external_content_id))
}

/// Inserts or updates the Content's row, marked as refreshed now, and returns its ID.
async fn save_content(
    transaction: &mut Transaction,
    metadata: &ContentMetadata,
) -> anyhow::Result<ContentId> {
    let content_type = metadata.id.content_type();
    let external_ids = metadata.external_ids.clone().with(&metadata.id);
    let id = sqlx::query_scalar!(
        r#"
        INSERT INTO contents (
            content_type, metadata_provider, external_ids, original_title, original_language,
            origin_country, release_date, genres, rating, backdrop, metadata_refreshed_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, now())
        ON CONFLICT (content_type, metadata_provider, main_external_id) DO UPDATE
        SET external_ids = EXCLUDED.external_ids,
            original_title = EXCLUDED.original_title,
            original_language = EXCLUDED.original_language,
            origin_country = EXCLUDED.origin_country,
            release_date = EXCLUDED.release_date,
            genres = EXCLUDED.genres,
            rating = EXCLUDED.rating,
            backdrop = EXCLUDED.backdrop,
            metadata_refreshed_at = EXCLUDED.metadata_refreshed_at
        RETURNING id
        "#,
        content_type as ContentType,
        content_type.metadata_provider() as _,
        Json(&external_ids) as _,
        metadata.original_title,
        metadata.original_language,
        metadata.origin_country,
        metadata.release_date.map(ToSqlx::to_sqlx) as _,
        &metadata.genres as _,
        metadata.rating,
        metadata.backdrop.as_ref().map(Json) as _,
    )
    .with_operation("INSERT", "contents")
    .fetch_one(&mut *transaction)
    .await
    .context("failed to save a Content")?;
    Ok(id)
}

/// Inserts or updates the Content's texts in each Locale.
async fn save_content_localizations(
    transaction: &mut Transaction,
    content_id: ContentId,
    metadata: &ContentMetadata,
) -> anyhow::Result<()> {
    let localizations: Vec<_> = metadata.texts.localize(&metadata.original_title).collect();
    let locales: Vec<_> = localizations
        .iter()
        .map(|localization| localization.locale)
        .collect();
    let titles: Vec<_> = localizations
        .iter()
        .map(|localization| localization.title)
        .collect();
    let overviews: Vec<_> = localizations
        .iter()
        .map(|localization| localization.overview)
        .collect();
    let posters: Vec<_> = localizations
        .iter()
        .map(|localization| localization.poster.map(Json))
        .collect();
    let trailer_urls: Vec<_> = localizations
        .iter()
        .map(|localization| localization.trailer_url)
        .collect();

    sqlx::query!(
        r#"
        WITH localization AS (
            SELECT *
            FROM UNNEST($2::locale[], $3::text[], $4::text[], $5::jsonb[], $6::text[])
                AS localization (locale, title, overview, poster, trailer_url)
        )
        INSERT INTO content_localizations (content_id, locale, title, overview, poster, trailer_url)
        SELECT $1, locale, title, overview, poster, trailer_url
        FROM localization
        ON CONFLICT (content_id, locale) DO UPDATE
        SET title = EXCLUDED.title,
            overview = EXCLUDED.overview,
            poster = EXCLUDED.poster,
            trailer_url = EXCLUDED.trailer_url
        WHERE (
            content_localizations.title, content_localizations.overview,
            content_localizations.poster, content_localizations.trailer_url
        ) IS DISTINCT FROM (
            EXCLUDED.title, EXCLUDED.overview, EXCLUDED.poster, EXCLUDED.trailer_url
        )
        "#,
        content_id as ContentId,
        &locales as &[Locale],
        &titles as &[&str],
        &overviews as &[Option<&str>],
        &posters as _,
        &trailer_urls as &[Option<&str>],
    )
    .with_operation("INSERT", "content_localizations")
    .execute(&mut *transaction)
    .await
    .context("failed to save a Content's texts")?;
    Ok(())
}

/// Inserts or updates the Content's credits, numbered in display order, and deletes the ones after.
async fn save_credits(
    transaction: &mut Transaction,
    content_id: ContentId,
    metadata: &ContentMetadata,
) -> anyhow::Result<()> {
    let credits = &metadata.credits;
    let kinds: Vec<_> = credits.iter().map(|credit| credit.kind).collect();
    let names: Vec<_> = credits.iter().map(|credit| credit.name.as_str()).collect();
    let characters: Vec<_> = credits
        .iter()
        .map(|credit| credit.character.as_deref())
        .collect();
    let photos: Vec<_> = credits
        .iter()
        .map(|credit| credit.photo.as_ref().map(Json))
        .collect();
    let external_ids: Vec<_> = credits
        .iter()
        .map(|credit| Json(&credit.external_ids))
        .collect();

    sqlx::query!(
        r#"
        WITH credit AS (
            SELECT (ordinality - 1)::integer AS position, kind, name, character, photo, external_ids
            FROM UNNEST($2::credit_kind[], $3::text[], $4::text[], $5::jsonb[], $6::jsonb[])
                WITH ORDINALITY AS credit (kind, name, character, photo, external_ids, ordinality)
        )
        INSERT INTO content_credits (
            content_id, position, kind, name, character, photo, external_ids
        )
        SELECT $1, position, kind, name, character, photo, external_ids
        FROM credit
        ON CONFLICT (content_id, position) DO UPDATE
        SET kind = EXCLUDED.kind,
            name = EXCLUDED.name,
            character = EXCLUDED.character,
            photo = EXCLUDED.photo,
            external_ids = EXCLUDED.external_ids
        WHERE (
            content_credits.kind, content_credits.name, content_credits.character,
            content_credits.photo, content_credits.external_ids
        ) IS DISTINCT FROM (
            EXCLUDED.kind, EXCLUDED.name, EXCLUDED.character, EXCLUDED.photo, EXCLUDED.external_ids
        )
        "#,
        content_id as ContentId,
        &kinds as _,
        &names as &[&str],
        &characters as &[Option<&str>],
        &photos as _,
        &external_ids as _,
    )
    .with_operation("INSERT", "content_credits")
    .execute(&mut *transaction)
    .await
    .context("failed to save a Content's credits")?;

    let credit_count = i32::try_from(credits.len()).context("too many credits")?;
    sqlx::query!(
        "DELETE FROM content_credits WHERE content_id = $1 AND position >= $2",
        content_id as ContentId,
        credit_count,
    )
    .with_operation("DELETE", "content_credits")
    .execute(&mut *transaction)
    .await
    .context("failed to delete a Content's former credits")?;
    Ok(())
}

/// Deletes the Content's Media its Metadata Provider no longer lists, then inserts or updates the
/// others, and their texts in each Locale. A Media is known by its type, group and number in it.
async fn save_media(
    transaction: &mut Transaction,
    content_id: ContentId,
    metadata: &ContentMetadata,
) -> anyhow::Result<()> {
    let media = &metadata.media;
    let media_types: Vec<_> = media.iter().map(|media| media.media_type).collect();
    let group_numbers: Vec<_> = media.iter().map(|media| media.group_number).collect();
    let numbers_in_group: Vec<_> = media.iter().map(|media| media.number_in_group).collect();

    // Compares the numbers, which a Movie doesn't have, as arrays: their equality counts two nulls
    // as equal, and unlike IS NOT DISTINCT FROM, Postgres can hash it, rather than compare every
    // TV Show Episode with every other
    sqlx::query!(
        r#"
        DELETE FROM media
        WHERE content_id = $1
            AND NOT EXISTS (
                SELECT FROM UNNEST($2::media_type[], $3::integer[], $4::integer[])
                    AS listed (media_type, group_number, number_in_group)
                WHERE listed.media_type = media.media_type
                    AND ARRAY[listed.group_number, listed.number_in_group]
                        = ARRAY[media.group_number, media.number_in_group]
            )
        "#,
        content_id as ContentId,
        &media_types as _,
        &group_numbers as &[Option<i32>],
        &numbers_in_group as &[Option<i32>],
    )
    .with_operation("DELETE", "media")
    .execute(&mut *transaction)
    .await
    .context("failed to delete a Content's former Media")?;

    let release_dates: Vec<_> = media
        .iter()
        .map(|media| media.release_date.map(ToSqlx::to_sqlx))
        .collect();
    let runtimes: Vec<_> = media.iter().map(|media| media.runtime_seconds).collect();
    let images: Vec<_> = media
        .iter()
        .map(|media| media.image.as_ref().map(Json))
        .collect();
    sqlx::query!(
        r#"
        WITH listed AS (
            SELECT *
            FROM UNNEST(
                $2::media_type[], $3::integer[], $4::integer[], $5::date[], $6::integer[],
                $7::jsonb[]
            ) AS listed (
                media_type, group_number, number_in_group, release_date, runtime_seconds, image
            )
        )
        INSERT INTO media (
            content_id, media_type, group_number, number_in_group, release_date, runtime_seconds,
            image
        )
        SELECT $1, media_type, group_number, number_in_group, release_date, runtime_seconds, image
        FROM listed
        ON CONFLICT (content_id, media_type, group_number, number_in_group) DO UPDATE
        SET release_date = EXCLUDED.release_date,
            runtime_seconds = EXCLUDED.runtime_seconds,
            image = EXCLUDED.image
        WHERE (media.release_date, media.runtime_seconds, media.image)
            IS DISTINCT FROM (EXCLUDED.release_date, EXCLUDED.runtime_seconds, EXCLUDED.image)
        "#,
        content_id as ContentId,
        &media_types as _,
        &group_numbers as &[Option<i32>],
        &numbers_in_group as &[Option<i32>],
        &release_dates as _,
        &runtimes as &[Option<i32>],
        &images as _,
    )
    .with_operation("INSERT", "media")
    .execute(&mut *transaction)
    .await
    .context("failed to save a Content's Media")?;

    // One row per Media and Locale, which finds its Media by type, group and number in it, as the
    // Media that didn't change don't return their IDs. The numbers compare as arrays, as above
    let localizations: Vec<_> = media
        .iter()
        .flat_map(|media| {
            media
                .texts
                .localize()
                .map(move |localization| (media, localization))
        })
        .collect();
    let localized_media_types: Vec<MediaType> = localizations
        .iter()
        .map(|(media, _)| media.media_type)
        .collect();
    let localized_group_numbers: Vec<_> = localizations
        .iter()
        .map(|(media, _)| media.group_number)
        .collect();
    let localized_numbers_in_group: Vec<_> = localizations
        .iter()
        .map(|(media, _)| media.number_in_group)
        .collect();
    let locales: Vec<_> = localizations
        .iter()
        .map(|(_, localization)| localization.locale)
        .collect();
    let titles: Vec<_> = localizations
        .iter()
        .map(|(_, localization)| localization.title)
        .collect();
    let overviews: Vec<_> = localizations
        .iter()
        .map(|(_, localization)| localization.overview)
        .collect();
    sqlx::query!(
        r#"
        WITH localization AS (
            SELECT *
            FROM UNNEST(
                $2::media_type[], $3::integer[], $4::integer[], $5::locale[], $6::text[], $7::text[]
            ) AS localization (media_type, group_number, number_in_group, locale, title, overview)
        )
        INSERT INTO media_localizations (media_id, locale, title, overview)
        SELECT media.id, localization.locale, localization.title, localization.overview
        FROM localization
        JOIN media ON media.content_id = $1
            AND media.media_type = localization.media_type
            AND ARRAY[media.group_number, media.number_in_group]
                = ARRAY[localization.group_number, localization.number_in_group]
        ON CONFLICT (media_id, locale) DO UPDATE
        SET title = EXCLUDED.title,
            overview = EXCLUDED.overview
        WHERE (media_localizations.title, media_localizations.overview)
            IS DISTINCT FROM (EXCLUDED.title, EXCLUDED.overview)
        "#,
        content_id as ContentId,
        &localized_media_types as _,
        &localized_group_numbers as &[Option<i32>],
        &localized_numbers_in_group as &[Option<i32>],
        &locales as &[Locale],
        &titles as &[Option<&str>],
        &overviews as &[Option<&str>],
    )
    .with_operation("INSERT", "media_localizations")
    .execute(&mut *transaction)
    .await
    .context("failed to save the texts of a Content's Media")?;
    Ok(())
}
