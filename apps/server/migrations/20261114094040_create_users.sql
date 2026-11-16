CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    username text NOT NULL UNIQUE,
    -- The password's hash with its algorithm, settings and salt, such as `$argon2id$v=19$…`
    password_hash text NOT NULL,
    locale text NOT NULL CHECK (locale IN ('en-US', 'fr-FR')),
    is_instance_administrator boolean NOT NULL DEFAULT false,
    inserted_at timestamptz NOT NULL DEFAULT now()
);

-- Only allow a single Instance Administrator
CREATE UNIQUE INDEX users_one_instance_administrator_idx ON users (is_instance_administrator)
WHERE is_instance_administrator;

-- A session keeps a User signed in on one device, such as a browser or the mobile app
CREATE TABLE sessions (
    -- The SHA-256 hash of the session token, which is never stored itself
    token_hash bytea PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users ON DELETE CASCADE,
    expires_at timestamptz NOT NULL
);

CREATE INDEX sessions_user_id_idx ON sessions (user_id);
