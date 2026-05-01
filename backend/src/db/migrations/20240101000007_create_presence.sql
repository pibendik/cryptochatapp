CREATE TABLE IF NOT EXISTS presence (
    user_id   UUID        PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    status    TEXT        NOT NULL CHECK (status IN ('online', 'away', 'offline')),
    last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_presence_last_seen ON presence(last_seen);
