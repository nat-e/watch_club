-- A language and country, such as a User's Locale, or the one a Content's texts are in. An enum
-- rather than a CHECK, so that every table that stores a Locale shares its list
CREATE TYPE locale AS ENUM ('en-US', 'fr-FR');

ALTER TABLE users DROP CONSTRAINT users_locale_check;
ALTER TABLE users ALTER COLUMN locale TYPE locale USING locale::locale;
