CREATE TABLE IF NOT EXISTS users (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    public_key   TEXT        NOT NULL UNIQUE,  -- Ed25519 public key (base64)
    display_name TEXT        NOT NULL,
    group_id     UUID        REFERENCES groups(id) ON DELETE SET NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_group_id   ON users(group_id);
CREATE INDEX IF NOT EXISTS idx_users_public_key ON users(public_key);
