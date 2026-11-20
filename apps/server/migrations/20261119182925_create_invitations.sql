-- The links the Instance Administrator shares so that new people can create their account
CREATE TABLE invitations (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    -- The code in the link. Kept as is rather than hashed, so that the Instance Administrator can
    -- copy the link again
    code text NOT NULL UNIQUE,
    -- The most Users it can create, or no limit when null
    max_uses bigint CHECK (max_uses > 0),
    -- The Users it created
    uses bigint NOT NULL DEFAULT 0,
    expires_at timestamptz NOT NULL,
    CONSTRAINT invitations_uses_within_max_uses CHECK (uses <= max_uses)
);
