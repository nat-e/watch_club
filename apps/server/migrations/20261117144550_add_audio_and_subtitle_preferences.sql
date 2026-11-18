-- The audio and subtitles each User wants videos to start with
ALTER TABLE users
    -- The Content's original language, or a Track Language
    ADD COLUMN audio_language text NOT NULL DEFAULT 'original'
        CHECK (audio_language IN ('original', 'en', 'fr')),
    -- No subtitles when null
    ADD COLUMN subtitle_language text CHECK (subtitle_language IN ('en', 'fr')),
    ADD COLUMN languages_without_subtitles text[] NOT NULL DEFAULT '{}'
        CHECK (languages_without_subtitles <@ ARRAY['en', 'fr']);

-- Like new Users: subtitles in the language of their Locale, except when the audio is already in it
UPDATE users
SET subtitle_language = split_part(locale, '-', 1),
    languages_without_subtitles = ARRAY[split_part(locale, '-', 1)];

-- The server sets them from the Locale of each new User
ALTER TABLE users
    ALTER COLUMN audio_language DROP DEFAULT,
    ALTER COLUMN languages_without_subtitles DROP DEFAULT;
