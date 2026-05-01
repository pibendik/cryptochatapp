CREATE TABLE ephemeral_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id TEXT NOT NULL,         -- public_key_hex (or UUID string) of creator
  group_id TEXT NOT NULL,           -- which group this belongs to
  state TEXT NOT NULL DEFAULT 'RAISED',  -- RAISED | ACTIVE | CLOSED
  created_at TIMESTAMPTZ DEFAULT NOW(),
  closed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '4 hours'  -- auto-expire
);

CREATE TABLE ephemeral_participants (
  session_id UUID REFERENCES ephemeral_sessions(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (session_id, user_id)
);

-- Index for fast lookup of active sessions per group
CREATE INDEX idx_ephemeral_sessions_group_state
  ON ephemeral_sessions(group_id, state)
  WHERE state IN ('RAISED', 'ACTIVE');

-- Cleanup expired sessions periodically
CREATE INDEX idx_ephemeral_sessions_expires_at
  ON ephemeral_sessions(expires_at);
