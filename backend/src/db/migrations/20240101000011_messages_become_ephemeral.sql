-- The messages table is now an ephemeral offline delivery queue.
-- Messages are deleted immediately after the recipient acknowledges receipt.
-- Message history lives on client devices (drift SQLite), NOT on the server.
-- This is the "sealed-envelope postal service" model:
--   the post office holds your mail until you pick it up, then destroys it.

-- Add acknowledged_at column for audit trail before deletion
ALTER TABLE messages ADD COLUMN IF NOT EXISTS acknowledged_at TIMESTAMPTZ;

-- Add index for efficient recipient queries (drain on reconnect)
CREATE INDEX IF NOT EXISTS idx_messages_recipient_unacked 
  ON messages(recipient_id, created_at) 
  WHERE acknowledged_at IS NULL;

-- Add automatic cleanup: delete acknowledged messages after 1 minute
-- (gives clients time to persist locally before server deletes)
-- BLOCKED(phase-3): replace with a periodic cleanup task in Rust
CREATE INDEX IF NOT EXISTS idx_messages_cleanup 
  ON messages(acknowledged_at) 
  WHERE acknowledged_at IS NOT NULL;
