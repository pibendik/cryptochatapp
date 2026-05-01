-- Migration: public_key_allowlist
-- Stores the set of Ed25519 public keys that are allowed to authenticate.
-- The server enforces this list in the /auth/verify handler after signature
-- verification succeeds; any key not present is rejected with 403 Forbidden.
CREATE TABLE IF NOT EXISTS public_key_allowlist (
    public_key_hex  TEXT        PRIMARY KEY,
    added_by        TEXT        NOT NULL,
    added_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    label           TEXT
);
