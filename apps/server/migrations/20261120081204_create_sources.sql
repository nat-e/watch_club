-- The kind of place WatchClub imports Media Files from
CREATE TYPE source_type AS ENUM ('filesystem', 'radarr', 'sonarr', 'sportarr');

-- A Source: where WatchClub imports Media Files from. A Filesystem Source is a folder on the
-- server. A Radarr, Sonarr or Sportarr Source is one of those apps, with the configuration of its
-- requests
CREATE TABLE sources (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    source_type source_type NOT NULL,
    media_type media_type NOT NULL,
    -- A Filesystem Source's folder
    path text,
    -- The app's address and API key. The key is encrypted with the server's ENCRYPTION_KEY, as
    -- the server's `EncryptedSecret` stores it
    url text,
    api_key_encrypted bytea,
    quality_profile_id integer,
    -- Shown with the Source, so that showing it doesn't call the app
    quality_profile_name text,
    -- The root folder, as the app sees it
    root_folder_path text,
    -- The root folder, as WatchClub sees it when that's another path, such as in Docker
    local_root_folder_path text,
    inserted_at timestamptz NOT NULL DEFAULT now(),

    -- Each Source Type has its own Source Configuration, and only that
    CONSTRAINT sources_configuration_matches_source_type CHECK (
        CASE source_type
            WHEN 'filesystem' THEN
                path IS NOT NULL
                AND num_nonnulls(
                    url, api_key_encrypted, quality_profile_id, quality_profile_name,
                    root_folder_path, local_root_folder_path
                ) = 0
            ELSE
                path IS NULL
                AND num_nulls(
                    url, api_key_encrypted, quality_profile_id, quality_profile_name,
                    root_folder_path
                ) = 0
        END
    ),
    -- Each app brings one Media Type
    CONSTRAINT sources_media_type_matches_source_type CHECK (
        CASE source_type
            WHEN 'radarr' THEN media_type = 'movie'
            WHEN 'sonarr' THEN media_type = 'tv_show_episode'
            WHEN 'sportarr' THEN media_type = 'sports_event'
            ELSE true
        END
    )
);
