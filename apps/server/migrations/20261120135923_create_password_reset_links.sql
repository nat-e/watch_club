-- The links the Instance Administrator shares so that a User who forgot their password can choose a
-- new one. A User has one at most: a new link replaces the last
CREATE TABLE password_reset_links (
    user_id uuid PRIMARY KEY REFERENCES users ON DELETE CASCADE,
    -- The SHA-256 hash of the token in the link, which is never stored itself
    token_hash bytea NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL
);
