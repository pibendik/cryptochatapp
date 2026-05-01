-- Migration: key_rotation
-- Creates the member_proposals table (if not already created by p4-consensus)
-- and adds the old_key_hex column used for ROTATE proposals.
--
-- A ROTATE proposal records:
--   old_key_hex      = the key being replaced (requester's current key)
--   target_key_hex   = the new key to be added to the allowlist
--   action           = 'ROTATE' | 'REMOVE'
--   status           = 'OPEN' | 'APPROVED' | 'REJECTED'
--   approval_count   = incremented each time a member calls POST /consensus/approve/:id
--   created_by       = public_key_hex of the requester

CREATE TABLE IF NOT EXISTS member_proposals (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    action         TEXT        NOT NULL,           -- 'ROTATE' | 'REMOVE'
    target_key_hex TEXT        NOT NULL,           -- new key (ROTATE) or compromised key (REMOVE)
    created_by     TEXT        NOT NULL,           -- public_key_hex of requester
    status         TEXT        NOT NULL DEFAULT 'OPEN',  -- 'OPEN' | 'APPROVED' | 'REJECTED'
    approval_count INT         NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add the old_key_hex column used by ROTATE proposals to record which key is
-- being replaced. NULL for REMOVE proposals.
ALTER TABLE member_proposals
    ADD COLUMN IF NOT EXISTS old_key_hex TEXT;
