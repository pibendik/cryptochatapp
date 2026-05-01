-- PostgreSQL initial schema for cryptochatapp
-- All payload/body columns store CIPHERTEXT only — the server never sees plaintext.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- provides gen_random_uuid()

-- ── Groups ──────────────────────────────────────────────────────────────────

CREATE TABLE groups (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Users ───────────────────────────────────────────────────────────────────

CREATE TABLE users (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    public_key   TEXT NOT NULL UNIQUE,   -- Ed25519 public key (base64)
    display_name TEXT NOT NULL,
    group_id     UUID REFERENCES groups(id) ON DELETE SET NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_group_id  ON users(group_id);
CREATE INDEX idx_users_public_key ON users(public_key);

-- ── Auth challenges ──────────────────────────────────────────────────────────

CREATE TABLE auth_challenges (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge  TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used       BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_auth_challenges_user_id    ON auth_challenges(user_id);
CREATE INDEX idx_auth_challenges_expires_at ON auth_challenges(expires_at);

-- ── Messages ─────────────────────────────────────────────────────────────────
-- payload is ALWAYS ciphertext (MLS envelope for group messages,
-- Double-Ratchet envelope for DMs). The server cannot decrypt this column.

CREATE TABLE messages (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id     UUID REFERENCES groups(id) ON DELETE CASCADE,  -- NULL for DMs
    recipient_id UUID REFERENCES users(id) ON DELETE CASCADE,   -- NULL for group messages
    sender_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    payload      BYTEA NOT NULL,  -- CIPHERTEXT ONLY — never store plaintext here
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_messages_target CHECK (
        (group_id IS NOT NULL AND recipient_id IS NULL) OR
        (group_id IS NULL AND recipient_id IS NOT NULL)
    )
);

COMMENT ON COLUMN messages.payload IS
    'Always ciphertext. MLS envelope for group messages; Double-Ratchet envelope for 1:1 DMs. The server cannot decrypt this column.';

CREATE INDEX idx_messages_group_id     ON messages(group_id, created_at);
CREATE INDEX idx_messages_recipient_id ON messages(recipient_id, created_at);
CREATE INDEX idx_messages_sender_id    ON messages(sender_id);

-- ── Forum posts ───────────────────────────────────────────────────────────────
-- payload is ALWAYS ciphertext — forum post body is encrypted client-side.
-- title may be stored in plaintext per the forum privacy trade-off decision (Open Question #2).

CREATE TABLE forum_posts (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title      TEXT NOT NULL,
    payload    BYTEA NOT NULL,  -- CIPHERTEXT ONLY — encrypted post body
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved   BOOLEAN NOT NULL DEFAULT FALSE
);

COMMENT ON COLUMN forum_posts.payload IS
    'Always ciphertext. Forum post body encrypted client-side before upload. The server cannot decrypt this column.';

CREATE INDEX idx_forum_posts_author_id  ON forum_posts(author_id);
CREATE INDEX idx_forum_posts_created_at ON forum_posts(created_at);

-- ── Presence ──────────────────────────────────────────────────────────────────

CREATE TABLE presence (
    user_id   UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    status    TEXT NOT NULL CHECK (status IN ('online', 'away', 'offline')),
    last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_presence_last_seen ON presence(last_seen);
