-- Migration: device_tokens
-- Stores per-user, per-platform push notification tokens.
-- The server uses these tokens to send silent wake-only pushes when a message
-- arrives for an offline user.  The payload sent to APNs/FCM contains NO
-- message content, sender name, or any other identifying information — only a
-- wake signal so the client opens a WebSocket and drains /messages/pending.
CREATE TABLE IF NOT EXISTS device_tokens (
    public_key_hex  TEXT        NOT NULL REFERENCES public_key_allowlist(public_key_hex) ON DELETE CASCADE,
    platform        TEXT        NOT NULL,   -- 'apns' | 'fcm'
    token           TEXT        NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (public_key_hex, platform)
);
