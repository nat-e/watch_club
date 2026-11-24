-- A piece of a Media, in watching order, such as a Sports Event's Prelims and Main Card. Most Media
-- have one, the whole of it. A Part stays when no file holds it anymore
CREATE TABLE media_parts (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    media_id uuid NOT NULL REFERENCES media ON DELETE CASCADE,
    -- Its place in watching order, from 1
    number integer NOT NULL CHECK (number > 0),

    UNIQUE (media_id, number)
);

-- A file that a Source brings, which holds Parts, or none when it's Unmatched
CREATE TABLE media_files (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    source_id uuid NOT NULL REFERENCES sources ON DELETE CASCADE,
    -- Where WatchClub sees it on the server
    path text NOT NULL,
    inserted_at timestamptz NOT NULL DEFAULT now(),

    UNIQUE (source_id, path)
);

-- The Parts each file holds. Copies of a Media share its Parts, and one file can hold the Parts of
-- two TV Show Episodes
CREATE TABLE media_file_parts (
    media_file_id uuid NOT NULL REFERENCES media_files ON DELETE CASCADE,
    media_part_id uuid NOT NULL REFERENCES media_parts ON DELETE CASCADE,
    PRIMARY KEY (media_file_id, media_part_id)
);

-- Lets deleting a Part, with its Media, find the rows that link files to it
CREATE INDEX media_file_parts_media_part_id ON media_file_parts (media_part_id);
