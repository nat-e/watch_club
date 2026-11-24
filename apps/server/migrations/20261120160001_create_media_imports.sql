-- What started a Media Import: a person, or the hourly schedule
CREATE TYPE media_import_trigger AS ENUM ('manual', 'scheduled');

-- The files of its Source a Media Import handles: those not imported yet, also the Unmatched ones,
-- or every file
CREATE TYPE files_to_import AS ENUM ('new', 'new_and_unmatched', 'all');

CREATE TYPE media_import_state AS ENUM ('waiting', 'running', 'completed', 'failed');

-- The reason a Media Import failed: its Source's app refused it, something went wrong, or the
-- server stopped while it ran
CREATE TYPE media_import_failure AS ENUM (
    'invalid_servarr_url', 'invalid_api_key', 'internal_error', 'interrupted'
);

-- One run that brings a Source's Media Files in, which its Source's history shows
CREATE TABLE media_imports (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    source_id uuid NOT NULL REFERENCES sources ON DELETE CASCADE,
    trigger media_import_trigger NOT NULL,
    files_to_import files_to_import NOT NULL,
    state media_import_state NOT NULL DEFAULT 'waiting',
    failure media_import_failure,
    -- The files it handles, once its Source listed them
    file_count integer CHECK (file_count >= 0),
    -- The files it handled so far: matched to their Content, saved as Unmatched, or failed, which
    -- stay as they were
    matched_file_count integer NOT NULL DEFAULT 0,
    unmatched_file_count integer NOT NULL DEFAULT 0,
    failed_file_count integer NOT NULL DEFAULT 0,
    -- The Media Files it removed, as its Source no longer lists them
    removed_file_count integer NOT NULL DEFAULT 0,
    -- When a person or the schedule started it
    started_at timestamptz NOT NULL DEFAULT now(),
    -- When its job began, which tells whether the server stopped while it ran
    job_started_at timestamptz,
    finished_at timestamptz,

    CONSTRAINT media_imports_failure_when_failed CHECK ((state = 'failed') = (failure IS NOT NULL))
);

-- Lists a Source's imports, the latest first
CREATE INDEX media_imports_source_id ON media_imports (source_id, started_at DESC);
