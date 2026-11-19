-- The kind of a Content
CREATE TYPE content_type AS ENUM ('movie', 'tv_show', 'sports_event', 'book');

-- A catalog that Content metadata comes from
CREATE TYPE metadata_provider AS ENUM ('tmdb', 'sportarr', 'hardcover');

-- The kind of Media, which decides the Content Type it belongs to
CREATE TYPE media_type AS ENUM ('movie', 'tv_show_episode', 'sports_event');

-- The part a person or an organization has in a Content, which the apps translate
CREATE TYPE credit_kind AS ENUM (
    'director', 'actor', 'author', 'illustrator', 'narrator', 'artist', 'league'
);

-- The kinds of story a Movie or a TV Show tells, which the apps translate
CREATE TYPE genre AS ENUM (
    'action', 'adventure', 'animation', 'comedy', 'crime', 'documentary', 'drama', 'family',
    'fantasy', 'history', 'horror', 'kids', 'music', 'mystery', 'news', 'politics', 'reality',
    'romance', 'science_fiction', 'soap', 'talk', 'thriller', 'tv_movie', 'war', 'western'
);

-- A Content, saved from its Metadata Provider the first time someone opens it. Its texts in each
-- Locale are in `content_localizations`
CREATE TABLE contents (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    content_type content_type NOT NULL,
    metadata_provider metadata_provider NOT NULL,
    -- Every External ID of the Content, by catalog, such as `{"tmdb": "603", "imdb": "tt0133093"}`
    external_ids jsonb NOT NULL,
    -- Its External ID at its Metadata Provider, which URLs carry. Generated, so it can't disagree
    -- with `external_ids`. A CASE, as Postgres doesn't take `external_ids ->> metadata_provider::text`
    -- for a generated column: add each new Metadata Provider to it
    main_external_id text NOT NULL GENERATED ALWAYS AS (
        CASE metadata_provider
            WHEN 'tmdb' THEN external_ids ->> 'tmdb'
            WHEN 'sportarr' THEN external_ids ->> 'sportarr'
            WHEN 'hardcover' THEN external_ids ->> 'hardcover'
        END
    ) STORED,
    original_title text NOT NULL,
    -- An ISO 639-1 code, such as `fr`
    original_language text,
    -- An ISO 3166-1 code, such as `FR`
    origin_country text,
    -- The day it came out, first aired or takes place
    release_date date,
    genres genre[] NOT NULL,
    -- The average of its votes out of 10, to one decimal, or null when too few people voted
    rating real,
    -- Images hold each size's URL, width and height
    backdrop jsonb,
    -- The last time it was saved from its Metadata Provider
    metadata_refreshed_at timestamptz NOT NULL,
    inserted_at timestamptz NOT NULL DEFAULT now(),

    -- TMDB numbers Movies and TV Shows apart, so the Content Type is part of the key
    UNIQUE (content_type, metadata_provider, main_external_id)
);

-- A Content's texts in one Locale. Saving fills a missing translation from another language, so
-- every Content has one row per Locale
CREATE TABLE content_localizations (
    content_id uuid NOT NULL REFERENCES contents ON DELETE CASCADE,
    locale locale NOT NULL,
    title text NOT NULL,
    overview text,
    poster jsonb,
    -- A YouTube URL
    trailer_url text,
    PRIMARY KEY (content_id, locale)
);

-- Who made a Content and who's in it, such as a Movie's director and actors
CREATE TABLE content_credits (
    content_id uuid NOT NULL REFERENCES contents ON DELETE CASCADE,
    -- Its place in display order, from 0
    position integer NOT NULL CHECK (position >= 0),
    kind credit_kind NOT NULL,
    name text NOT NULL,
    -- The character an actor plays
    character text,
    photo jsonb,
    -- The person's IDs in outside catalogs, such as `{"tmdb": "1245"}`
    external_ids jsonb NOT NULL,
    PRIMARY KEY (content_id, position)
);

-- What Users play inside a Content: a Movie's one Media, each TV Show Episode, a Sports Event's one
-- Media. Its texts in each Locale are in `media_localizations`
CREATE TABLE media (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    content_id uuid NOT NULL REFERENCES contents ON DELETE CASCADE,
    media_type media_type NOT NULL,
    -- A season, or null for a Movie or a Sports Event
    group_number integer,
    -- An episode, or null for a Movie or a Sports Event
    number integer,
    -- The day it came out, aired or takes place, which tells whether it's out
    release_date date,
    runtime_seconds integer CHECK (runtime_seconds > 0),
    image jsonb,

    -- Also lists a Content's Media, in order
    UNIQUE NULLS NOT DISTINCT (content_id, media_type, group_number, number)
);

-- A Media's texts in one Locale, filled like `content_localizations`. Null when no language has
-- them, such as a TV Show Episode that's announced without a title
CREATE TABLE media_localizations (
    media_id uuid NOT NULL REFERENCES media ON DELETE CASCADE,
    locale locale NOT NULL,
    title text,
    overview text,
    PRIMARY KEY (media_id, locale)
);
