CREATE TABLE IF NOT EXISTS messages (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id     UUID        REFERENCES groups(id) ON DELETE CASCADE,  -- NULL for DMs
    recipient_id UUID        REFERENCES users(id)  ON DELETE CASCADE,  -- NULL for group messages
    sender_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    payload      BYTEA       NOT NULL,  -- ciphertext, never plaintext
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_messages_target CHECK (
        (group_id IS NOT NULL AND recipient_id IS NULL) OR
        (group_id IS NULL     AND recipient_id IS NOT NULL)
    )
);

COMMENT ON COLUMN messages.payload IS
    'Always ciphertext. MLS envelope for group messages; Double-Ratchet envelope for 1:1 DMs. The server cannot decrypt this column.';

CREATE INDEX IF NOT EXISTS idx_messages_group_id     ON messages(group_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_recipient_id ON messages(recipient_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id    ON messages(sender_id);
