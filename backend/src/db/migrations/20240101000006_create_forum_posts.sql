CREATE TABLE IF NOT EXISTS forum_posts (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id  UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title      TEXT        NOT NULL,
    payload    BYTEA       NOT NULL,  -- ciphertext, never plaintext
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved   BOOLEAN     NOT NULL DEFAULT FALSE
);

COMMENT ON COLUMN forum_posts.payload IS
    'Always ciphertext. Forum post body encrypted client-side before upload. The server cannot decrypt this column.';

CREATE INDEX IF NOT EXISTS idx_forum_posts_author_id  ON forum_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_created_at ON forum_posts(created_at);
